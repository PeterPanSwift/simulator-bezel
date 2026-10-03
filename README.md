# Simulator Bezel

Automatically frame your iPhone screenshots — from the Simulator or a real device — with a device bezel, the moment they land on your Desktop.

iPhone 截圖(模擬器或實機)存到桌面後,自動套上實機外框(bezel)。

| Simulator screenshot 模擬器截圖 | Auto-framed 自動加框後 |
|:---:|:---:|
| <img src="docs/demo-before.png" width="285"> | <img src="docs/demo-after.png" width="300"> |

**[English](#english)** | **[繁體中文](#繁體中文)**

---

## English

Save a screenshot in the iPhone Simulator (`Cmd+S`), or take one on a real iPhone through iPhone Mirroring, and a framed `... Bezel.png` appears next to it on your Desktop within seconds — no clicks, no drag-and-drop, fully automatic.

### Requirements

- macOS (uses the built-in launchd; no third-party dependencies)
- Xcode or Command Line Tools, for compiling at install time (`xcode-select --install`)

### Install

```bash
git clone https://github.com/PeterPanSwift/simulator-bezel.git
cd simulator-bezel
./install.sh
```

Then press <kbd>Cmd</kbd>+<kbd>S</kbd> in the Simulator to save a screenshot to your Desktop and watch it get framed. If macOS asks for permission to access your Desktop on the first run, click Allow.

### How it works

- `install.sh` compiles `bezel-frame`, deploys it together with `bezel.png` to `~/Library/Application Support/add-bezel/`, and registers a launchd LaunchAgent (`~/Library/LaunchAgents/com.add-bezel.plist`).
- The LaunchAgent uses **WatchPaths** to watch `~/Desktop`: whenever the folder changes, the system launches `bezel-frame --scan` once. Idle cost is zero (kernel event notification, not polling), and a scan that finds nothing to do finishes in about 16 ms.
- `bezel-frame` auto-detects the transparent screen cutout in `bezel.png` (the largest transparent region not connected to the image edge), draws the screenshot underneath and the bezel on top — so **swapping in a different bezel image requires no code changes**.
- A file is processed when its name starts with `Screenshot` (or `Simulator Screenshot`) and contains `iPhone` — this covers both Simulator names like `Screenshot iPhone 17 Pro 08-05-2026 at 16.42.20.png` and real-device names like `Screenshot Peter's iPhone 08-06-2026 at 00.26.35.png`. Files that already have a `... Bezel.png` counterpart are skipped (idempotent — rescanning never redoes work).

### Custom bezel

Replace `bezel.png` with any frame image whose **screen area is transparent**, then run `./install.sh` again. The cutout position and size are detected at runtime.

The bundled `bezel.png` is an iPhone 17 Pro (Cosmic Orange) with a 1206×2622 screen cutout — a 1:1 match for Simulator screenshot resolution.

### iPhone Duo: pick a bezel

<img src="docs/duo-picker.png" width="700" alt="iPhone Duo bezel picker">

Device-specific bezels live in `bezels/<device name>/`. When a screenshot belongs to that device — its file name contains the folder name (e.g. `Screenshot iPhone Duo …`), or, for iPhone Duo, its aspect ratio matches (so real-device screenshots work too) — a dialog shows a live preview of the screenshot in every bezel and asks which one to apply. Your last choice is preselected. Cancelling skips that screenshot; the Desktop watcher won't ask about it again (the list is kept in `~/Library/Caches/add-bezel-skipped.txt`).

The bundled `bezels/iPhone Duo/` holds Starlight (open), Starlight (closed, portrait) and Midnight (open). A leading number sets the order and is hidden from the label (`2 星白色・闔上直向.png` → “星白色・闔上直向”). Drop in more PNGs with transparent screens and run `./install.sh` again.

### Right-click menu

`install.sh` gives you two Finder right-click entry points, both of which frame any image regardless of its filename and save the result next to the original as `... Bezel.png`:

- **Quick Action** — right-click an image → **Quick Actions → Add Bezel**. Installed as an Automator workflow at `~/Library/Services/Add Bezel.workflow`; also selectable from the Finder preview pane and the Touch Bar.
- **Open With** — right-click an image → **Open With → Add Bezel**, or drop images onto `~/Applications/Add Bezel.app` (an AppleScript droplet compiled with `osacompile`).

If a menu item doesn't show up right away, relaunch Finder or log out and back in.

### Manual run

```bash
./add-bezel.sh            # scan ~/Desktop
./add-bezel.sh ~/Pictures # scan a specific folder
```

Or frame a single file:

```bash
./bezel-frame screenshot.png            # bezel.png / bezels/ taken from the binary's folder, writes "screenshot Bezel.png"
./bezel-frame bezel.png screenshot.png output.png   # explicit bezel, no picker dialog
```

### Troubleshooting

- Execution log: `~/Library/Caches/add-bezel.log` — one line per scan (`visible=` screenshots seen, `framed=` newly framed).
- If nothing happens, check the LaunchAgent: `launchctl print gui/$(id -u)/com.add-bezel`.

### Uninstall

```bash
./uninstall.sh
```

Framed images on your Desktop are left untouched.

---

## 繁體中文

iPhone 的截圖存到桌面後,**自動**套上實機外框(bezel),產生適合分享、放簡報的圖片。模擬器截圖與透過「iPhone 鏡像輸出」拍的實機截圖都支援。

存下 `Screenshot iPhone 17 Pro ... .png` 幾秒後,旁邊就會自動出現加好外框的 `Screenshot iPhone 17 Pro ... Bezel.png`,完全不用動手。

### 需求

- macOS(使用內建的 launchd,不需安裝任何第三方工具)
- Xcode 或 Command Line Tools(安裝時編譯用:`xcode-select --install`)

### 安裝

```bash
git clone https://github.com/PeterPanSwift/simulator-bezel.git
cd simulator-bezel
./install.sh
```

安裝後在模擬器按 <kbd>Cmd</kbd>+<kbd>S</kbd> 存一張截圖到桌面試試。第一次執行時若 macOS 詢問是否允許取用「桌面」,請按允許。

### 運作原理

- `install.sh` 會把編譯好的 `bezel-frame` 和 `bezel.png` 部署到 `~/Library/Application Support/add-bezel/`,並註冊一個 launchd LaunchAgent(`~/Library/LaunchAgents/com.add-bezel.plist`)。
- LaunchAgent 用 **WatchPaths** 監看 `~/Desktop`:桌面一有變動,系統就喚起 `bezel-frame --scan` 掃描一次。平常完全不耗資源(核心事件通知,不是輪詢),沒有新截圖時一次掃描約 16 毫秒就結束。
- `bezel-frame` 會自動偵測 `bezel.png` 透明螢幕開口的位置(不與圖片邊緣相連的最大透明區域),把截圖墊在下層、外框疊在上層合成,所以**換不同外框圖不需要改任何程式**。
- 檔名開頭是 `Screenshot`(或 `Simulator Screenshot`)且含有 `iPhone` 的檔案才會處理 — 同時涵蓋模擬器的 `Screenshot iPhone 17 Pro 08-05-2026 at 16.42.20.png` 與實機的 `Screenshot 彼得潘 的 iPhone 08-06-2026 at 00.26.35.png`。已經有對應 `... Bezel.png` 的會跳過(冪等,重複掃描不會重做)。

### 自訂外框

把 `bezel.png` 換成任何**螢幕區域為透明**的外框圖,重新執行 `./install.sh` 即可。開口位置與大小都是執行時自動偵測的。

附的 `bezel.png` 是 iPhone 17 Pro(宇宙橙),螢幕開口 1206×2622,和模擬器截圖解析度 1:1 對應。

### iPhone Duo:選擇外框

<img src="docs/duo-picker.png" width="700" alt="iPhone Duo bezel picker">

裝置專屬外框放在 `bezels/<裝置名稱>/`。截圖屬於該裝置時 — 檔名含資料夾名稱(例如 `Screenshot iPhone Duo …`),或 iPhone Duo 的長寬比相符(實機截圖也能認出)— 會跳出對話框,用這張截圖預覽套上每款外框的樣子,讓你選擇要套用哪一款,預設選上次用的那款。按「取消」就跳過這張,桌面自動掃描之後不會再問(記錄在 `~/Library/Caches/add-bezel-skipped.txt`)。

附的 `bezels/iPhone Duo/` 有星白色(展開)、星白色(闔上直向)與夜空色(展開)。檔名開頭的數字決定排列順序,不會顯示在選項上(`2 星白色・闔上直向.png` → 「星白色・闔上直向」)。要加外框就放入螢幕透明的 PNG,再重跑 `./install.sh`。

### 右鍵選單

`install.sh` 提供兩種 Finder 右鍵入口,都能幫**任何圖片**加框(不限檔名格式),加框後的 `... Bezel.png` 存在原圖旁邊:

- **快速動作** — 對圖片按右鍵 →「**快速動作**」→「**Add Bezel**」。以 Automator workflow 形式安裝在 `~/Library/Services/Add Bezel.workflow`,Finder 預覽面板也能點。
- **打開檔案的應用程式** — 對圖片按右鍵 →「**打開檔案的應用程式**」→「**Add Bezel**」,或把圖片拖到 `~/Applications/Add Bezel.app` 圖示上(用 `osacompile` 編譯的 AppleScript droplet)。

如果選單一開始沒出現,重新啟動 Finder 或登出再登入即可。

### 手動執行

```bash
./add-bezel.sh            # 掃描 ~/Desktop
./add-bezel.sh ~/Pictures # 掃描指定資料夾
```

或單張合成:

```bash
./bezel-frame 截圖.png                 # 外框取自執行檔同目錄的 bezel.png / bezels/,輸出「截圖 Bezel.png」
./bezel-frame bezel.png 截圖.png 輸出.png  # 指定外框,不跳選擇對話框
```

### 疑難排解

- 執行記錄:`~/Library/Caches/add-bezel.log`,每次掃描都會留一行(`visible=看到幾張截圖 framed=這次加框幾張`)。
- 若一直沒反應,檢查 LaunchAgent 狀態:`launchctl print gui/$(id -u)/com.add-bezel`。

### 解除安裝

```bash
./uninstall.sh
```

已加框的圖片不會被刪除。

## License

MIT
