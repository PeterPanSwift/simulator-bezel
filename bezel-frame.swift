// bezel-frame: composite a simulator screenshot under a device bezel PNG.
//
// Usage:
//   bezel-frame <bezel.png> <screenshot.png> <output.png>   # single file
//   bezel-frame --scan <bezel.png> <dir>                    # frame every unprocessed
//                                                           # iPhone simulator screenshot in dir
//
// The bezel's screen cutout must be transparent. The cutout is found by
// flood-filling transparent pixels from the image center, so the screenshot
// is drawn only inside the opening and never leaks past the rounded corners.
import Foundation
import CoreGraphics
import ImageIO

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func loadImage(_ path: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fail("cannot load image: \(path)")
    }
    return img
}

func frame(bezelPath: String, shotPath: String, outPath: String) {
    let bezel = loadImage(bezelPath)
    let shot = loadImage(shotPath)
    let bw = bezel.width, bh = bezel.height
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    // Rasterize bezel to inspect alpha. Buffer row 0 is the visual top.
    var bezelBuf = [UInt8](repeating: 0, count: bw * bh * 4)
    guard let scan = CGContext(data: &bezelBuf, width: bw, height: bh, bitsPerComponent: 8,
                               bytesPerRow: bw * 4, space: srgb,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create scan context")
    }
    scan.draw(bezel, in: CGRect(x: 0, y: 0, width: bw, height: bh))

    // Flood-fill the transparent screen cutout from the center.
    var inside = [Bool](repeating: false, count: bw * bh)
    func transparent(_ i: Int) -> Bool { bezelBuf[i * 4 + 3] < 128 }
    let start = (bh / 2) * bw + bw / 2
    guard transparent(start) else { fail("bezel center is opaque; expected a transparent screen cutout") }
    var stack = [start]
    inside[start] = true
    var minX = bw, maxX = 0, minY = bh, maxY = 0
    while let i = stack.popLast() {
        let x = i % bw, y = i / bw
        if x < minX { minX = x }; if x > maxX { maxX = x }
        if y < minY { minY = y }; if y > maxY { maxY = y }
        if x > 0 && !inside[i - 1] && transparent(i - 1) { inside[i - 1] = true; stack.append(i - 1) }
        if x < bw - 1 && !inside[i + 1] && transparent(i + 1) { inside[i + 1] = true; stack.append(i + 1) }
        if y > 0 && !inside[i - bw] && transparent(i - bw) { inside[i - bw] = true; stack.append(i - bw) }
        if y < bh - 1 && !inside[i + bw] && transparent(i + bw) { inside[i + bw] = true; stack.append(i + bw) }
    }
    let screenW = maxX - minX + 1
    let screenH = maxY - minY + 1

    // Rasterize the screenshot aspect-filled over the cutout, then keep only
    // the pixels inside the flood-filled opening.
    var shotBuf = [UInt8](repeating: 0, count: bw * bh * 4)
    guard let shotCtx = CGContext(data: &shotBuf, width: bw, height: bh, bitsPerComponent: 8,
                                  bytesPerRow: bw * 4, space: srgb,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create screenshot context")
    }
    let screenRect = CGRect(x: minX, y: bh - maxY - 1, width: screenW, height: screenH)
    let scale = max(CGFloat(screenW) / CGFloat(shot.width), CGFloat(screenH) / CGFloat(shot.height))
    let drawW = CGFloat(shot.width) * scale
    let drawH = CGFloat(shot.height) * scale
    shotCtx.interpolationQuality = .high
    shotCtx.draw(shot, in: CGRect(x: screenRect.midX - drawW / 2, y: screenRect.midY - drawH / 2,
                                  width: drawW, height: drawH))
    for i in 0..<(bw * bh) where !inside[i] {
        shotBuf[i * 4] = 0; shotBuf[i * 4 + 1] = 0; shotBuf[i * 4 + 2] = 0; shotBuf[i * 4 + 3] = 0
    }
    guard let maskedShot = shotCtx.makeImage() else { fail("cannot create masked screenshot") }

    // Compose: masked screenshot below, bezel on top.
    guard let out = CGContext(data: nil, width: bw, height: bh, bitsPerComponent: 8,
                              bytesPerRow: 0, space: srgb,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create output context")
    }
    let full = CGRect(x: 0, y: 0, width: bw, height: bh)
    out.draw(maskedShot, in: full)
    out.draw(bezel, in: full)

    guard let result = out.makeImage(),
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                     "public.png" as CFString, 1, nil) else {
        fail("cannot create output image")
    }
    CGImageDestinationAddImage(dest, result, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(outPath)") }
    print("wrote \(outPath)")
}

// 執行記錄(除錯用): 每次掃描都留一行,可判斷自動化有沒有真的執行
func logScan(_ message: String) {
    let logPath = NSString(string: "~/Library/Caches/add-bezel.log").expandingTildeInPath
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let line = "\(fmt.string(from: Date())) pid=\(ProcessInfo.processInfo.processIdentifier) \(message)\n"
    if let handle = FileHandle(forWritingAtPath: logPath) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
    } else {
        try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}

func scan(bezelPath: String, dir: String) {
    let fm = FileManager.default
    guard let names = try? fm.contentsOfDirectory(atPath: dir) else {
        logScan("scan FAILED: cannot read \(dir) (檢查「桌面」資料夾存取權)")
        fail("cannot read directory: \(dir) — grant this binary access to the folder")
    }
    // 模擬器截圖「Screenshot iPhone 17 Pro …」與實機截圖「Screenshot 某人的 iPhone …」
    // 裝置名稱的位置不同,所以只要求開頭是 Screenshot、名稱含 iPhone。
    let shots = names.filter { name in
        name.hasSuffix(".png") && !name.hasSuffix(" Bezel.png")
            && (name.hasPrefix("Screenshot ") || name.hasPrefix("Simulator Screenshot "))
            && name.contains("iPhone")
    }
    var made = 0
    for name in shots.sorted() {
        let outName = String(name.dropLast(4)) + " Bezel.png"
        if names.contains(outName) { continue }
        frame(bezelPath: bezelPath, shotPath: dir + "/" + name, outPath: dir + "/" + outName)
        made += 1
    }
    logScan("scan dir=\(dir) visible=\(shots.count) framed=\(made)")
}

let args = CommandLine.arguments
if args.count == 4 && args[1] == "--scan" {
    scan(bezelPath: args[2], dir: args[3])
} else if args.count == 4 {
    frame(bezelPath: args[1], shotPath: args[2], outPath: args[3])
} else {
    fail("usage: bezel-frame <bezel.png> <screenshot.png> <output.png>\n       bezel-frame --scan <bezel.png> <dir>")
}
