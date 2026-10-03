// bezel-frame: composite a simulator screenshot under a device bezel PNG.
//
// Usage:
//   bezel-frame <screenshot.png>                            # bezel.png beside the binary,
//                                                           # writes "<name> Bezel.png"
//   bezel-frame <bezel.png> <screenshot.png> <output.png>   # single file, explicit bezel
//   bezel-frame --scan <bezel.png> <dir>                    # frame every unprocessed
//                                                           # iPhone simulator screenshot in dir
//
// The bezel's screen cutout must be transparent. The cutout is the largest
// transparent region not connected to the image border, so the screenshot
// is drawn only inside the opening and never leaks past the rounded corners.
//
// Device-specific bezels live in bezels/<device name>/*.png next to bezel.png.
// When a screenshot belongs to such a device (by file name, or by aspect ratio
// for devices listed in aspectHints) a dialog asks which bezel to apply.
// A leading number in the file name sets the order and is hidden from the label,
// e.g. "1 星白色・展開.png" shows as "星白色・展開".
import Foundation
import CoreGraphics
import ImageIO
import AppKit

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

func writePNG(_ image: CGImage, to outPath: String) {
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                     "public.png" as CFString, 1, nil) else {
        fail("cannot create output image")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(outPath)") }
    print("wrote \(outPath)")
}

func compose(bezel: CGImage, shot: CGImage) -> CGImage {
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

    // Label transparent regions: -1 = connected to the border (outside the device),
    // 1... = enclosed regions. The largest enclosed one is the screen cutout.
    // (The center isn't always inside it — an unfolded foldable has its hinge there.)
    var label = [Int32](repeating: 0, count: bw * bh)
    func transparent(_ i: Int) -> Bool { bezelBuf[i * 4 + 3] < 128 }
    var stack: [Int] = []
    func fill(from seed: Int, as id: Int32) -> (count: Int, minX: Int, maxX: Int, minY: Int, maxY: Int) {
        var count = 0, minX = bw, maxX = 0, minY = bh, maxY = 0
        label[seed] = id
        stack.append(seed)
        while let i = stack.popLast() {
            count += 1
            let x = i % bw, y = i / bw
            if x < minX { minX = x }; if x > maxX { maxX = x }
            if y < minY { minY = y }; if y > maxY { maxY = y }
            func visit(_ n: Int) {
                if label[n] == 0 && transparent(n) { label[n] = id; stack.append(n) }
            }
            if x > 0 { visit(i - 1) }
            if x < bw - 1 { visit(i + 1) }
            if y > 0 { visit(i - bw) }
            if y < bh - 1 { visit(i + bw) }
        }
        return (count, minX, maxX, minY, maxY)
    }
    for x in 0..<bw {
        for i in [x, (bh - 1) * bw + x] where label[i] == 0 && transparent(i) { _ = fill(from: i, as: -1) }
    }
    for y in 0..<bh {
        for i in [y * bw, y * bw + bw - 1] where label[i] == 0 && transparent(i) { _ = fill(from: i, as: -1) }
    }
    var best: (id: Int32, count: Int, minX: Int, maxX: Int, minY: Int, maxY: Int) = (0, 0, 0, 0, 0, 0)
    var nextID: Int32 = 1
    for i in 0..<(bw * bh) where label[i] == 0 && transparent(i) {
        let r = fill(from: i, as: nextID)
        if r.count > best.count { best = (nextID, r.count, r.minX, r.maxX, r.minY, r.maxY) }
        nextID += 1
    }
    guard best.count > 0 else { fail("bezel has no enclosed transparent screen cutout") }
    let screenW = best.maxX - best.minX + 1
    let screenH = best.maxY - best.minY + 1

    // Rasterize the screenshot aspect-filled over the cutout, then keep only
    // the pixels inside the cutout.
    var shotBuf = [UInt8](repeating: 0, count: bw * bh * 4)
    guard let shotCtx = CGContext(data: &shotBuf, width: bw, height: bh, bitsPerComponent: 8,
                                  bytesPerRow: bw * 4, space: srgb,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create screenshot context")
    }
    let screenRect = CGRect(x: best.minX, y: bh - best.maxY - 1, width: screenW, height: screenH)
    let scale = max(CGFloat(screenW) / CGFloat(shot.width), CGFloat(screenH) / CGFloat(shot.height))
    let drawW = CGFloat(shot.width) * scale
    let drawH = CGFloat(shot.height) * scale
    shotCtx.interpolationQuality = .high
    shotCtx.draw(shot, in: CGRect(x: screenRect.midX - drawW / 2, y: screenRect.midY - drawH / 2,
                                  width: drawW, height: drawH))
    for i in 0..<(bw * bh) where label[i] != best.id {
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
    guard let result = out.makeImage() else { fail("cannot create output image") }
    return result
}

func frame(bezelPath: String, shotPath: String, outPath: String) {
    writePNG(compose(bezel: loadImage(bezelPath), shot: loadImage(shotPath)), to: outPath)
}

// MARK: - 多款外框(bezels/<裝置名稱>/)

struct BezelVariant {
    let label: String
    let path: String
}

// 檔名不含裝置名稱時(例如實機截圖「Screenshot 某人的 iPhone …」),改用截圖短邊/長邊比例判斷
let aspectHints: [String: ClosedRange<Double>] = ["iPhone Duo": 0.64...0.74]

func variantsByDevice(bezelDir: String) -> [String: [BezelVariant]] {
    let fm = FileManager.default
    let root = bezelDir + "/bezels"
    var result: [String: [BezelVariant]] = [:]
    for device in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
        let files = ((try? fm.contentsOfDirectory(atPath: root + "/" + device)) ?? [])
            .filter { $0.lowercased().hasSuffix(".png") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        guard !files.isEmpty else { continue }
        result[device] = files.map { name in
            let label = String(name.dropLast(4))
                .replacingOccurrences(of: #"^\d+[ _.-]*"#, with: "", options: .regularExpression)
            return BezelVariant(label: label, path: root + "/" + device + "/" + name)
        }
    }
    return result
}

func detectDevice(shotPath: String, shot: CGImage, devices: [String: [BezelVariant]]) -> String? {
    let name = (shotPath as NSString).lastPathComponent
    if let device = devices.keys.sorted(by: { $0.count > $1.count }).first(where: { name.contains($0) }) {
        return device
    }
    if name.contains("iPad") { return nil }
    let ratio = Double(min(shot.width, shot.height)) / Double(max(shot.width, shot.height))
    return devices.keys.first { aspectHints[$0]?.contains(ratio) == true }
}

final class ChoiceController: NSObject {
    var radios: [NSButton] = []
    var selected = 0
    @objc func pickRadio(_ sender: NSButton) { select(sender.tag) }
    @objc func pickImage(_ sender: NSClickGestureRecognizer) { if let v = sender.view { select(v.tag) } }
    func select(_ index: Int) {
        selected = index
        for (i, r) in radios.enumerated() { r.state = i == index ? .on : .off }
    }
}

// 跳出對話框讓使用者挑外框;預覽圖直接用這張截圖合成。回傳選中的索引,取消則回傳 nil
func chooseVariant(device: String, variants: [BezelVariant], previews: [CGImage], shotName: String) -> Int? {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let defaults = UserDefaults(suiteName: "com.add-bezel")
    let lastKey = "lastChoice.\(device)"
    let controller = ChoiceController()
    let boxH: CGFloat = variants.count <= 3 ? 360 : 260
    let maxW: CGFloat = variants.count <= 3 ? 340 : 240

    let row = NSStackView()
    row.orientation = .horizontal
    row.alignment = .top
    row.spacing = 32
    for (i, variant) in variants.enumerated() {
        let preview = previews[i]
        let aspect = CGFloat(preview.width) / CGFloat(preview.height)
        let imageView = NSImageView(image: NSImage(cgImage: preview, size: .zero))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.tag = i
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: min(maxW, boxH * aspect)).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: boxH).isActive = true
        imageView.addGestureRecognizer(NSClickGestureRecognizer(target: controller,
                                                                action: #selector(ChoiceController.pickImage(_:))))
        let radio = NSButton(radioButtonWithTitle: variant.label, target: controller,
                             action: #selector(ChoiceController.pickRadio(_:)))
        radio.tag = i
        controller.radios.append(radio)

        let column = NSStackView(views: [imageView, radio])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 14
        row.addArrangedSubview(column)
    }
    let last = defaults?.string(forKey: lastKey)
    controller.select(variants.firstIndex { ($0.path as NSString).lastPathComponent == last } ?? 0)
    row.layoutSubtreeIfNeeded()
    row.frame = NSRect(origin: .zero, size: row.fittingSize)

    let alert = NSAlert()
    alert.messageText = "選擇 \(device) 外框"
    alert.informativeText = "已偵測到 \(device)，請選擇要套用的外框。\n\(shotName)"
    alert.addButton(withTitle: "套用外框")
    alert.addButton(withTitle: "取消").keyEquivalent = "\u{1b}"
    alert.accessoryView = row
    // 從 launchd 背景執行時不一定能搶到前景,先把視窗浮在最上層
    alert.window.level = .floating
    app.activate()
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }

    let chosen = controller.selected
    defaults?.set((variants[chosen].path as NSString).lastPathComponent, forKey: lastKey)
    return chosen
}

// 依截圖選外框並輸出;回傳 false 代表使用者取消
@discardableResult
func frameAsking(defaultBezel: String, shotPath: String, outPath: String) -> Bool {
    let shot = loadImage(shotPath)
    let devices = variantsByDevice(bezelDir: (defaultBezel as NSString).deletingLastPathComponent)
    guard let device = detectDevice(shotPath: shotPath, shot: shot, devices: devices),
          let variants = devices[device] else {
        writePNG(compose(bezel: loadImage(defaultBezel), shot: shot), to: outPath)
        return true
    }
    let previews = variants.map { compose(bezel: loadImage($0.path), shot: shot) }
    if variants.count == 1 {
        writePNG(previews[0], to: outPath)
        return true
    }
    let shotName = (shotPath as NSString).lastPathComponent
    guard let chosen = chooseVariant(device: device, variants: variants, previews: previews,
                                     shotName: shotName) else {
        print("canceled \(shotPath)")
        return false
    }
    writePNG(previews[chosen], to: outPath)
    return true
}

// MARK: - 掃描資料夾

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

// 在選外框對話框按「取消」的截圖記在這裡,之後掃描就不再詢問
let skippedPath = NSString(string: "~/Library/Caches/add-bezel-skipped.txt").expandingTildeInPath

func scan(bezelPath: String, dir: String) {
    let fm = FileManager.default
    var skipped = Set(((try? String(contentsOfFile: skippedPath, encoding: .utf8)) ?? "")
        .split(separator: "\n").map(String.init))
    var visible = 0, made = 0, canceled = 0
    // 對話框開著時可能又有新截圖存到桌面,所以處理完再掃一次,直到沒有新工作
    while true {
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
        visible = shots.count
        var handled = 0
        for name in shots.sorted() {
            let shotPath = dir + "/" + name
            let outName = String(name.dropLast(4)) + " Bezel.png"
            if names.contains(outName) || skipped.contains(shotPath) { continue }
            handled += 1
            if frameAsking(defaultBezel: bezelPath, shotPath: shotPath, outPath: dir + "/" + outName) {
                made += 1
            } else {
                canceled += 1
                skipped.insert(shotPath)
                try? (skipped.sorted().joined(separator: "\n") + "\n")
                    .write(toFile: skippedPath, atomically: true, encoding: .utf8)
            }
        }
        if handled == 0 { break }
    }
    logScan("scan dir=\(dir) visible=\(visible) framed=\(made) canceled=\(canceled)")
}

let args = CommandLine.arguments
if args.count == 4 && args[1] == "--scan" {
    scan(bezelPath: args[2], dir: args[3])
} else if args.count == 4 {
    frame(bezelPath: args[1], shotPath: args[2], outPath: args[3])
} else if args.count == 2 && args[1] != "--help" && args[1] != "-h" {
    // 只傳截圖:bezel 用執行檔旁邊的 bezel.png(或 bezels/ 裡的裝置專屬外框),輸出為「<原名> Bezel.png」
    let exe = URL(fileURLWithPath: args[0]).resolvingSymlinksInPath()
    let bezel = exe.deletingLastPathComponent().appendingPathComponent("bezel.png").path
    let shot = URL(fileURLWithPath: args[1])
    let base = shot.deletingPathExtension().lastPathComponent
    let out = shot.deletingLastPathComponent().appendingPathComponent(base + " Bezel.png").path
    if frameAsking(defaultBezel: bezel, shotPath: shot.path, outPath: out) { print(out) }
} else {
    fail("usage: bezel-frame <screenshot.png>                  (bezel.png 取自執行檔同目錄,輸出「<原名> Bezel.png」)\n       bezel-frame <bezel.png> <screenshot.png> <output.png>\n       bezel-frame --scan <bezel.png> <dir>")
}
