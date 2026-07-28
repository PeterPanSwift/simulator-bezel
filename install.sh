#!/bin/zsh
# 安裝 Simulator Bezel 自動加框:
# 編譯 bezel-frame、部署到 Application Support、註冊 launchd 監看桌面
set -e
HERE="${0:A:h}"
APP_SUPPORT="$HOME/Library/Application Support/add-bezel"
PLIST="$HOME/Library/LaunchAgents/com.add-bezel.plist"
LABEL="com.add-bezel"

if ! command -v swiftc >/dev/null; then
  echo "找不到 swiftc,請先安裝 Xcode 或 Command Line Tools(xcode-select --install)" >&2
  exit 1
fi

echo "==> 編譯 bezel-frame…"
swiftc -O "$HERE/bezel-frame.swift" -o "$HERE/bezel-frame"

echo "==> 部署到 $APP_SUPPORT"
mkdir -p "$APP_SUPPORT"
cp "$HERE/bezel-frame" "$HERE/bezel.png" "$APP_SUPPORT/"

echo "==> 建立 LaunchAgent"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$APP_SUPPORT/bezel-frame</string>
		<string>--scan</string>
		<string>$APP_SUPPORT/bezel.png</string>
		<string>$HOME/Desktop</string>
	</array>
	<key>WatchPaths</key>
	<array>
		<string>$HOME/Desktop</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>10</integer>
	<key>StandardOutPath</key>
	<string>$HOME/Library/Caches/add-bezel-launchd.log</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Caches/add-bezel-launchd.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo ""
echo "✅ 安裝完成!桌面出現新的 iPhone 模擬器截圖時,會自動產生「... Bezel.png」。"
echo "   若 macOS 詢問是否允許取用「桌面」,請按允許。"
echo "   執行記錄:~/Library/Caches/add-bezel.log"
