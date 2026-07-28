#!/bin/zsh
# add-bezel.sh — 掃描桌面上的 iPhone 模擬器截圖,套上 bezel.png 後另存為「... Bezel.png」
# 用法: add-bezel.sh [資料夾]   (預設掃描 ~/Desktop)
# 掃描與合成邏輯都在 bezel-frame 裡(--scan 模式);執行記錄在 ~/Library/Caches/add-bezel.log
set -u
DIR="${1:-$HOME/Desktop}"
HERE="${0:A:h}"
exec "$HERE/bezel-frame" --scan "$HERE/bezel.png" "$DIR"
