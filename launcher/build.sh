#!/bin/bash
# ───────────────────────────────────────────────────────
# FaceFusion4.8 黄金定制版 — macOS 构建脚本
# 在 GitHub Actions macos-latest runner 上运行
# ───────────────────────────────────────────────────────
set -euo pipefail

# ── 配置 ────────────────────────────────────────────
FFMPEG_URL="https://github.com/eugeneware/ffmpeg-static/releases/download/b6.0/osx-arm64"

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORK_DIR/build"
APP_DIR="$BUILD_DIR/FaceFusion.app"
RESOURCES="$APP_DIR/Contents/Resources"
MACOS="$APP_DIR/Contents/MacOS"

echo "==================================================="
echo " FaceFusion4.8 DMG 构建"
echo " 工作目录: $WORK_DIR"
echo " 构建目录: $BUILD_DIR"
echo "==================================================="

# ── 清理旧构建 ─────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$RESOURCES" "$MACOS"

# ══════════════════════════════════════════════════════
# Step 1: 拷贝 setup-python 提供的 Python 3.12
# ══════════════════════════════════════════════════════
echo "[1/8] 准备 Python 3.12..."
PYTHON_SRC="${SETUP_PYTHON_PATH:-$(dirname "$(which python3)")/..}"
echo "  Python 源路径: $PYTHON_SRC"
mkdir -p "$RESOURCES/python"
cp -r "$PYTHON_SRC"/* "$RESOURCES/python/" 2>/dev/null || \
  cp -r "$(dirname "$(which python3)")/../"* "$RESOURCES/python/"
if [ ! -f "$RESOURCES/python/bin/python3" ]; then
  mkdir -p "$RESOURCES/python/bin"
  cp "$(which python3)" "$RESOURCES/python/bin/python3"
fi
PYTHON_BIN="$RESOURCES/python/bin/python3"
echo "  Python: $($PYTHON_BIN --version 2>&1)"

# ══════════════════════════════════════════════════════
# Step 2: 创建 venv 并安装依赖
# ══════════════════════════════════════════════════════
echo "[2/8] 创建虚拟环境..."
"$PYTHON_BIN" -m venv "$RESOURCES/venv"
VENV_PYTHON="$RESOURCES/venv/bin/python3"
VENV_PIP="$RESOURCES/venv/bin/pip"

echo "  安装 FaceFusion 依赖..."
"$VENV_PIP" install --quiet --upgrade pip
"$VENV_PIP" install --quiet \
    gradio-rangeslider==0.0.8 \
    gradio==5.44.1 \
    numpy==2.2.1 \
    onnx==1.21.0 \
    onnxruntime==1.24.4 \
    opencv-python==4.13.0.92 \
    tqdm==4.67.3 \
    scipy==1.17.1

echo "  安装 PyInstaller (构建工具)..."
"$VENV_PIP" install --quiet pyinstaller

# ══════════════════════════════════════════════════════
# Step 3: 准备 FaceFusion 源码 + 中文化
# ══════════════════════════════════════════════════════
echo "[3/8] 准备 FaceFusion 源码..."
cp -r "$WORK_DIR/facefusion-master" "$RESOURCES/facefusion"

echo "  应用中文化补丁 (覆盖 locales.py)..."
cp "$WORK_DIR/launcher/patches/locales_with_zh.py" "$RESOURCES/facefusion/facefusion/locales.py"

# ══════════════════════════════════════════════════════
# Step 4: 预下载 AI 模型
# ══════════════════════════════════════════════════════
echo "[4/8] 预下载 AI 模型 (约 2.5 GB，需耐心等待)..."
export PATH="$RESOURCES:$PATH"
cd "$RESOURCES/facefusion"
"$VENV_PYTHON" facefusion.py force-download
echo "  模型下载完成"

# ══════════════════════════════════════════════════════
# Step 5: 下载 ffmpeg + curl
# ══════════════════════════════════════════════════════
echo "[5/8] 准备 ffmpeg + curl..."
cp "$(which ffmpeg)" "$RESOURCES/ffmpeg" 2>/dev/null || \
    curl -fsSL "https://osx-universal-binary.static.ffmpeg.org/ffmpeg" -o "$RESOURCES/ffmpeg"
chmod +x "$RESOURCES/ffmpeg" 2>/dev/null || true

cp "$(which curl)" "$RESOURCES/curl" 2>/dev/null || true
chmod +x "$RESOURCES/curl" 2>/dev/null || true

echo "  ffmpeg: $($RESOURCES/ffmpeg -version 2>&1 | head -1 || echo 'ok')"
echo "  curl:   $($RESOURCES/curl --version 2>&1 | head -1 || echo 'ok')"

# ══════════════════════════════════════════════════════
# Step 6: 用 PyInstaller 编译启动器
# ══════════════════════════════════════════════════════
echo "[6/8] 编译启动器 (PyInstaller)..."
cd "$WORK_DIR"

# 图标处理：没有就跳过
ICON_LINE=""
if [ -f "$WORK_DIR/assets/icon.icns" ]; then
	ICON_LINE="icon='$WORK_DIR/assets/icon.icns',"
fi

cat > /tmp/launcher.spec <<SPEC
# -*- mode: python -*-
a = Analysis(
    ['$WORK_DIR/launcher/launcher.py'],
    pathex=['$WORK_DIR/launcher'],
    binaries=[],
    datas=[],
    hiddenimports=['tkinter', 'threading', 'subprocess', 'json', 'pathlib'],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
)
pyz = PYZ(a.pure, a.zipped_data)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='FaceFusionLauncher',
    debug=False,
    bootloader_ignore_signals=False,
    strip=True,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    target_arch='arm64',
)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=True,
    upx=False,
    name='FaceFusionLauncherBuild',
)
app = BUNDLE(
    coll,
    name='FaceFusion.app',
    ${ICON_LINE}
    bundle_identifier='com.facefusion.gold-4-8',
    info_plist={
        'CFBundleName': 'FaceFusion4.8',
        'CFBundleDisplayName': 'FaceFusion4.8 黄金定制版',
        'CFBundleVersion': '4.8.0',
        'CFBundleShortVersionString': '4.8',
        'LSMinimumSystemVersion': '13.0',
        'NSHighResolutionCapable': True,
        'LSRequiresNativeExecution': True,
    },
)
SPEC

"$VENV_PYTHON" -m PyInstaller /tmp/launcher.spec --distpath "$BUILD_DIR/pyinstaller_dist" --workpath /tmp/pyi_build --clean --noconfirm 2>&1 | tail -5

# ══════════════════════════════════════════════════════
# Step 7: 组装 .app Bundle
# ══════════════════════════════════════════════════════
echo "[7/8] 组装 .app Bundle..."

PYI_EXE="$(find "$BUILD_DIR/pyinstaller_dist" -name FaceFusionLauncher -type f | head -1)"

if [ -n "$PYI_EXE" ]; then
    cp "$PYI_EXE" "$MACOS/FaceFusionLauncher"
    chmod +x "$MACOS/FaceFusionLauncher"
    echo "  可执行文件: $MACOS/FaceFusionLauncher"
else
    echo "  WARNING: BUNDLE 模式不可用，使用手动组装"
    cp "$WORK_DIR/launcher/launcher.py" "$MACOS/FaceFusionLauncher.py"
fi

# 复制图标 (放错地方也不影响运行)
cp "$WORK_DIR/assets/icon.icns" "$RESOURCES/icon.icns" 2>/dev/null || echo "  (图标文件暂缺，使用默认)"

# 复制 Info.plist
cp "$WORK_DIR/launcher/Info.plist" "$APP_DIR/Contents/Info.plist"
echo "  Bundle 组装完成"

# ══════════════════════════════════════════════════════
# Step 8: 制作 DMG
# ══════════════════════════════════════════════════════
echo "[8/8] 制作 DMG..."

DMG_DIR="$BUILD_DIR/dmg"
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"
ln -sf /Applications "$DMG_DIR/Applications"

DMG_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.dmg"

if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "FaceFusion4.8" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "FaceFusion.app" 180 170 \
        --hide-extension "FaceFusion.app" \
        --app-drop-link 480 170 \
        "$DMG_FILE" \
        "$DMG_DIR/"
else
    hdiutil create -volname "FaceFusion4.8" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_FILE"
fi

echo ""
echo "==================================================="
echo " 构建完成!"
echo " DMG: $DMG_FILE"
ls -lh "$DMG_FILE"
echo "==================================================="
