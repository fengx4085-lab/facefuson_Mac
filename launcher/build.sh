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
MODEL_DIR="$RESOURCES/facefusion/.assets/models"
CACHE_DIR="$WORK_DIR/facefusion-master/.assets"

# 如果缓存中有模型（Step 3 的 cp 已带入），force-download 会跳过已有文件
if [ -d "$CACHE_DIR/models" ] && [ "$(ls -1 "$CACHE_DIR/models" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "  检测到缓存模型 ($(du -sh "$CACHE_DIR/models" | cut -f1))，将跳过已下载文件"
fi

export PATH="$RESOURCES:$PATH"
cd "$RESOURCES/facefusion"
"$VENV_PYTHON" facefusion.py force-download
echo "  模型下载完成"

# 写回缓存目录，让 GitHub Actions cache 下次能命中
mkdir -p "$CACHE_DIR"
cp -r "$MODEL_DIR" "$CACHE_DIR/"
echo "  模型已同步至缓存目录"

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

# 全力减肥：模型缓存、pip、__pycache__、PyInstaller 临时文件
echo "  释放空间..."
rm -rf /tmp/pyi_build "$BUILD_DIR/pyinstaller_dist"
find "$RESOURCES/venv" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$RESOURCES/facefusion" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
rm -rf "$RESOURCES/venv/lib/python3.12/site-packages/pip" 2>/dev/null || true
rm -rf "$RESOURCES/venv/share" 2>/dev/null || true
rm -rf "$CACHE_DIR"/models 2>/dev/null || true
echo "=== 剩余空间 ==="
df -h / | tail -1
du -sh "$APP_DIR" 2>/dev/null || true

# 准备 DMG staging 目录
DMG_STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
mv "$APP_DIR" "$DMG_STAGING/"
ln -sf /Applications "$DMG_STAGING/Applications"

# 尝试创建 DMG；磁盘空间不够则回退到 zip
DMG_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.dmg"
DMG_OK=0
hdiutil create -volname "FaceFusion4.8" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_FILE" 2>&1 && DMG_OK=1 || true

if [ "$DMG_OK" -eq 1 ] && [ -f "$DMG_FILE" ]; then
    echo "  DMG 创建成功"
    ls -lh "$DMG_FILE"
else
    echo "  hdiutil 失败，回退为 zip"
    ZIP_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.zip"
    cd "$DMG_STAGING"
    zip -rq "$ZIP_FILE" .
    echo "  ZIP: $(ls -lh "$ZIP_FILE" | awk '{print $5}')"
fi

echo "=== 最终剩余空间 ==="
df -h / | tail -1
