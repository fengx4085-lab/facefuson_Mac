#!/bin/bash
# ───────────────────────────────────────────────────────
# FaceFusion4.8 黄金定制版 — Mac 环境准备脚本
# 在 M4 Mac 上运行一次即可
# ───────────────────────────────────────────────────────
set -euo pipefail

echo "=== 安装 Homebrew ==="
if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo ""
echo "=== 安装必要工具 ==="
brew install python@3.12 python-tk@3.12 ffmpeg create-dmg curl

echo ""
echo "=== 验证 ==="
echo "Python:  $(python3.12 --version)"
echo "FFmpeg: $(ffmpeg -version 2>&1 | head -1)"
echo "Tkinter: $(python3.12 -c 'import tkinter; print("OK")' 2>&1)"
echo "create-dmg: $(command -v create-dmg && echo 'OK' || echo '未安装(非必须)')"

echo ""
echo "=== 完成 ==="
echo "现在可以运行: cd 项目目录 && bash launcher/build.sh"
