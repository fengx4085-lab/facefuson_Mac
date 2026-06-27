#!/bin/bash
# ───────────────────────────────────────────────────────
# FaceFusion4.8 黄金定制版 — macOS 构建脚本
# 在真实 macOS (M4 / Apple Silicon) 上运行
# 要求: macOS 14+, Python 3.12, brew (ffmpeg, create-dmg 可选)
# ───────────────────────────────────────────────────────
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORK_DIR/build"
APP_DIR="$BUILD_DIR/FaceFusion.app"
RESOURCES="$APP_DIR/Contents/Resources"
MACOS="$APP_DIR/Contents/MacOS"
CACHE_MODELS="$WORK_DIR/facefusion-master/.assets/models"

echo "==================================================="
echo " FaceFusion4.8 黄金定制版 DMG 构建"
echo " 工作目录: $WORK_DIR"
echo "==================================================="

# ── 清理旧构建 ─────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$RESOURCES" "$MACOS"

# ══════════════════════════════════════════════════════
# Step 1: 拷贝系统 Python 3.12 到 bundle
# ══════════════════════════════════════════════════════
echo "[1/8] 准备 Python 3.12..."

PYTHON3=$(which python3.12 2>/dev/null || which python3 2>/dev/null)
echo "  Python: $PYTHON3 ($($PYTHON3 --version 2>&1))"

PY_VER=$($PYTHON3 --version 2>&1 | awk '{print $2}')
if [[ ! "$PY_VER" =~ ^3\.12 ]]; then
    echo "  错误: 需要 Python 3.12，当前是 $PY_VER"
    echo "  请安装: brew install python@3.12"
    exit 1
fi

PY_HOME=$(dirname "$(dirname "$PYTHON3")")
mkdir -p "$RESOURCES/python/bin" "$RESOURCES/python/lib"

# 只拷贝 bin/ 和 lib/ —— share/ 和 include/ 全是系统无关文件
# （locale、CUPS 模板、Apache 图标、bash 文档），FaceFusion 用不到
# --no-perms --no-owner: 不复制属性，彻底避免 Permission denied
rsync -rltD --no-perms --no-owner --no-group "$PY_HOME/bin/" "$RESOURCES/python/bin/"
rsync -rltD --no-perms --no-owner --no-group "$PY_HOME/lib/" "$RESOURCES/python/lib/"

if [ ! -f "$RESOURCES/python/bin/python3" ]; then
    mkdir -p "$RESOURCES/python/bin"
    cp "$PYTHON3" "$RESOURCES/python/bin/python3"
fi

PYTHON_BIN="$RESOURCES/python/bin/python3"
echo "  Bundle Python: $($PYTHON_BIN --version 2>&1)"

# ══════════════════════════════════════════════════════
# Step 2: 创建 venv 并安装 pip 依赖
# ══════════════════════════════════════════════════════
echo "[2/8] 创建虚拟环境 + 安装依赖..."
"$PYTHON_BIN" -m venv "$RESOURCES/venv"
VENV_PYTHON="$RESOURCES/venv/bin/python3"
VENV_PIP="$RESOURCES/venv/bin/pip"

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

echo "  安装 PyInstaller..."
"$VENV_PIP" install --quiet pyinstaller

echo "  venv: $(du -sh "$RESOURCES/venv" | cut -f1)"

# ══════════════════════════════════════════════════════
# Step 3: FaceFusion 源码 + 中文化
# ══════════════════════════════════════════════════════
echo "[3/8] 准备 FaceFusion 源码 + 中文化..."
cp -r "$WORK_DIR/facefusion-master" "$RESOURCES/facefusion"
cp "$WORK_DIR/launcher/patches/locales_with_zh.py" "$RESOURCES/facefusion/facefusion/locales.py"
echo "  完成"

# ══════════════════════════════════════════════════════
# Step 4: 预下载 AI 模型
# ══════════════════════════════════════════════════════
echo "[4/8] 预下载 AI 模型..."

export PATH="$RESOURCES:$PATH"
MODEL_DIR="$RESOURCES/facefusion/.assets/models"

if [ -d "$CACHE_MODELS" ] && [ "$(ls -1 "$CACHE_MODELS" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "  缓存命中 ($(du -sh "$CACHE_MODELS" | cut -f1))，跳过已下载文件"
    mkdir -p "$(dirname "$MODEL_DIR")"
    ln -sf "$CACHE_MODELS" "$MODEL_DIR"
else
    echo "  首次下载，无缓存"
    mkdir -p "$MODEL_DIR"
fi

cd "$RESOURCES/facefusion"
"$VENV_PYTHON" facefusion.py force-download
echo "  模型: $(du -sh "$MODEL_DIR" | cut -f1)"

# 如果是 symlink 指向缓存，固化为真实目录
if [ -L "$MODEL_DIR" ]; then
    TARGET=$(readlink "$MODEL_DIR")
    rm "$MODEL_DIR"
    cp -Rl "$TARGET" "$MODEL_DIR" 2>/dev/null || cp -R "$TARGET" "$MODEL_DIR"
fi

echo "  磁盘: $(df -h / | tail -1 | awk '{print $4 " 可用"}')"

# ══════════════════════════════════════════════════════
# Step 5: ffmpeg + curl
# ══════════════════════════════════════════════════════
echo "[5/8] 准备 ffmpeg + curl..."

FFMPEG_BIN=$(which ffmpeg 2>/dev/null || echo '')
if [ -n "$FFMPEG_BIN" ]; then
    cp "$FFMPEG_BIN" "$RESOURCES/ffmpeg"
else
    echo "  ffmpeg 未安装，正在下载..."
    curl -fsSL "https://osx-universal-binary.static.ffmpeg.org/ffmpeg" -o "$RESOURCES/ffmpeg"
fi
chmod +x "$RESOURCES/ffmpeg"

CURL_BIN=$(which curl 2>/dev/null || echo '')
if [ -n "$CURL_BIN" ]; then
    cp "$CURL_BIN" "$RESOURCES/curl"
    chmod +x "$RESOURCES/curl"
fi

echo "  ffmpeg: $($RESOURCES/ffmpeg -version 2>&1 | head -1 || echo 'ok')"
echo "  curl:   $([ -f "$RESOURCES/curl" ] && $RESOURCES/curl --version 2>&1 | head -1 || echo 'ok')"

# ══════════════════════════════════════════════════════
# Step 6: PyInstaller 编译启动器
# ══════════════════════════════════════════════════════
echo "[6/8] 编译启动器 (PyInstaller)..."
cd "$WORK_DIR"

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

"$VENV_PYTHON" -m PyInstaller /tmp/launcher.spec \
    --distpath "$BUILD_DIR/pyinstaller_dist" \
    --workpath /tmp/pyi_build \
    --clean --noconfirm 2>&1 | tail -5

# ══════════════════════════════════════════════════════
# Step 7: 组装 .app Bundle
# ══════════════════════════════════════════════════════
echo "[7/8] 组装 .app Bundle..."

PYI_EXE="$(find "$BUILD_DIR/pyinstaller_dist" -name FaceFusionLauncher -type f | head -1)"

if [ -z "$PYI_EXE" ]; then
    echo "  错误: PyInstaller 未生成 FaceFusionLauncher"
    exit 1
fi

cp "$PYI_EXE" "$MACOS/FaceFusionLauncher"
chmod +x "$MACOS/FaceFusionLauncher"
echo "  可执行文件: $MACOS/FaceFusionLauncher"

cp "$WORK_DIR/assets/icon.icns" "$RESOURCES/icon.icns" 2>/dev/null || echo "  (图标暂缺，使用默认)"
cp "$WORK_DIR/launcher/Info.plist" "$APP_DIR/Contents/Info.plist"
echo "  Bundle 组装完成"

# ══════════════════════════════════════════════════════
# Step 8: 清理 + 打包 DMG
# ══════════════════════════════════════════════════════
echo "[8/8] 制作 DMG..."

# 清理冗余文件
rm -rf /tmp/pyi_build "$BUILD_DIR/pyinstaller_dist" /tmp/launcher.spec
find "$RESOURCES/venv" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$RESOURCES/facefusion" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
rm -rf "$RESOURCES/venv/lib/python3.12/site-packages/pip" 2>/dev/null || true

echo "  .app 大小: $(du -sh "$APP_DIR" | cut -f1)"

# 准备 DMG 源目录
DMG_SRC="$BUILD_DIR/dmg_src"
rm -rf "$DMG_SRC"
mkdir -p "$DMG_SRC"
mv "$APP_DIR" "$DMG_SRC/"
ln -sf /Applications "$DMG_SRC/Applications"

DMG_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.dmg"

echo "  创建 DMG..."
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
        "$DMG_SRC/"
else
    hdiutil create -volname "FaceFusion4.8" \
        -srcfolder "$DMG_SRC" \
        -ov -format UDZO \
        "$DMG_FILE"
fi

echo ""
echo "==================================================="
echo "  构建完成!"
echo "  DMG: $DMG_FILE ($(ls -lh "$DMG_FILE" | awk '{print $5}'))"
echo "  磁盘剩余: $(df -h / | tail -1 | awk '{print $4}')"
echo "==================================================="
