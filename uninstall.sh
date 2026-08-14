#!/bin/zsh
# 解除安裝 Simulator Bezel 自動加框(不會動到桌面上已加框的圖片)
launchctl bootout "gui/$(id -u)/com.add-bezel" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.add-bezel.plist"
rm -rf "$HOME/Library/Application Support/add-bezel"
rm -f "$HOME/Library/Caches/add-bezel.log" "$HOME/Library/Caches/add-bezel-launchd.log"
if [ -d "$HOME/Applications/Add Bezel.app" ]; then
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u "$HOME/Applications/Add Bezel.app" 2>/dev/null || true
  rm -rf "$HOME/Applications/Add Bezel.app"
fi
echo "✅ 已解除安裝。"
