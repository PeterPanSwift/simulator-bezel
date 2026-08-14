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

echo "==> 建立右鍵選單 App(~/Applications/Add Bezel.app)"
APP="$HOME/Applications/Add Bezel.app"
mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" "$HERE/Add Bezel.applescript"
# 宣告可開啟圖片檔,右鍵「打開檔案的應用程式」才會列出這個 App
PB=/usr/libexec/PlistBuddy
INFO="$APP/Contents/Info.plist"
$PB -c "Delete :CFBundleDocumentTypes" "$INFO" 2>/dev/null || true
$PB -c "Add :CFBundleDocumentTypes array" "$INFO"
$PB -c "Add :CFBundleDocumentTypes:0 dict" "$INFO"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Image" "$INFO"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$INFO"
$PB -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$INFO"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$INFO"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.image" "$INFO"
$PB -c "Set :CFBundleIdentifier com.add-bezel.app" "$INFO" 2>/dev/null || $PB -c "Add :CFBundleIdentifier string com.add-bezel.app" "$INFO"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP"

echo "==> 安裝快速動作(~/Library/Services/Add Bezel.workflow)"
mkdir -p "$HOME/Library/Services"
rm -rf "$HOME/Library/Services/Add Bezel.workflow"
cp -R "$HERE/Add Bezel.workflow" "$HOME/Library/Services/"
# 手動複製的 workflow 預設不會被啟用,直接寫入 pbs 偏好設定啟用它
ENABLE='{ "enabled_context_menu" = 1; "enabled_services_menu" = 1; "presentation_modes" = { ContextMenu = 1; ServicesMenu = 1; }; }'
defaults write pbs NSServicesStatus -dict-add '"com.apple.Automator.Add Bezel - Add Bezel - runWorkflowAsService"' "$ENABLE"
defaults write pbs NSServicesStatus -dict-add '"(null) - Add Bezel - runWorkflowAsService"' "$ENABLE"
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo ""
echo "✅ 安裝完成!"
echo "   • 桌面出現新的 iPhone 截圖時,會自動產生「... Bezel.png」。"
echo "   • 任何圖片也可以按右鍵 → 快速動作 → Add Bezel,"
echo "     或右鍵 → 打開檔案的應用程式 → Add Bezel 手動加框。"
echo "   若 macOS 詢問是否允許取用「桌面」,請按允許。"
echo "   執行記錄:~/Library/Caches/add-bezel.log"
