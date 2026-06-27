#!/bin/bash
# ───────────────────────────────────────────────────────
# FaceFusion4.8 黄金定制版 — macOS 构建脚本
# 在 GitHub Actions macos-latest runner 上运行
# ───────────────────────────────────────────────────────
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORK_DIR/build"
APP_DIR="$BUILD_DIR/FaceFusion.app"
RESOURCES="$APP_DIR/Contents/Resources"
MACOS="$APP_DIR/Contents/MacOS"
CACHE_DIR="$WORK_DIR/facefusion-master/.assets"

echo "==================================================="
echo " FaceFusion4.8 DMG 构建"
echo " 工作目录: $WORK_DIR"
echo "==================================================="

# ── 清理旧构建 ─────────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$RESOURCES" "$MACOS"

# ══════════════════════════════════════════════════════
# Step 1: 拷贝 Python 3.12
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

# 清理 pip 缓存
"$VENV_PIP" cache purge -q 2>/dev/null || true
rm -rf "$RESOURCES/venv/lib/python3.12/site-packages/pip" 2>/dev/null || true

# ══════════════════════════════════════════════════════
# Step 3: FaceFusion 源码 + 中文化
# ══════════════════════════════════════════════════════
echo "[3/8] 准备 FaceFusion 源码..."
cp -r "$WORK_DIR/facefusion-master" "$RESOURCES/facefusion"

echo "  应用中文化补丁..."
cp "$WORK_DIR/launcher/patches/locales_with_zh.py" "$RESOURCES/facefusion/facefusion/locales.py"

# ══════════════════════════════════════════════════════
# Step 4: 预下载 AI 模型（用 symlink 避免复制）
# ══════════════════════════════════════════════════════
echo "[4/8] 预下载 AI 模型..."

ASSETS_LINK="$RESOURCES/facefusion/.assets"
MODEL_DIR="$ASSETS_LINK/models"
mkdir -p "$CACHE_DIR"

# 用 symlink 让 force-download 直接写入缓存目录，不产生副本
if [ ! -d "$ASSETS_LINK" ] && [ ! -L "$ASSETS_LINK" ]; then
    ln -sf "$CACHE_DIR" "$ASSETS_LINK"
fi

if [ -d "$MODEL_DIR" ] && [ "$(ls -1 "$MODEL_DIR" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "  检测到缓存模型 ($(du -sh "$MODEL_DIR" | cut -f1))，将跳过已下载文件"
fi

export PATH="$RESOURCES:$PATH"
cd "$RESOURCES/facefusion"
"$VENV_PYTHON" facefusion.py force-download
echo "  模型下载完成 → $(du -sh "$MODEL_DIR" | cut -f1)"

# 模型已在缓存中（symlink 写入），无需额外复制
echo "  disk usage:"
df -h / | tail -1

# ══════════════════════════════════════════════════════
# Step 5: ffmpeg + curl
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

if [ -n "$PYI_EXE" ]; then
    cp "$PYI_EXE" "$MACOS/FaceFusionLauncher"
    chmod +x "$MACOS/FaceFusionLauncher"
    echo "  可执行文件: $MACOS/FaceFusionLauncher"
else
    echo "  WARNING: BUNDLE 模式不可用"
    cp "$WORK_DIR/launcher/launcher.py" "$MACOS/FaceFusionLauncher.py"
fi

cp "$WORK_DIR/assets/icon.icns" "$RESOURCES/icon.icns" 2>/dev/null || echo "  (图标暂缺)"
cp "$WORK_DIR/launcher/Info.plist" "$APP_DIR/Contents/Info.plist"
echo "  Bundle 组装完成"

# ══════════════════════════════════════════════════════
# Step 8: 清理 → 解决 symlink → 打包
# ══════════════════════════════════════════════════════
echo "[8/8] 制作 DMG..."

# 清理
rm -rf /tmp/pyi_build "$BUILD_DIR/pyinstaller_dist" /tmp/launcher.spec
find "$RESOURCES/venv" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$RESOURCES/facefusion" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true

# 关键：.assets 是 symlink 指向 cache → 改为真实目录让 DMG 可以跟随
# (hdiutil -srcfolder 不跟随外部 symlink)
echo "  固化模型目录..."
if [ -L "$ASSETS_LINK" ]; then
    ACTUAL_CACHE="$(readlink "$ASSETS_LINK")"
    rm -f "$ASSETS_LINK"
    mkdir -p "$ASSETS_LINK"
    # 硬链接到 cache（瞬间完成，不占额外空间）
    cp -Rl "$ACTUAL_CACHE"/* "$ASSETS_LINK/" 2>/dev/null || cp -R "$ACTUAL_CACHE"/* "$ASSETS_LINK/"
fi

# 模型已在 .app 内固化，删除缓存释放空间
rm -rf "$CACHE_DIR"/models 2>/dev/null || true

echo "=== 剩余空间 ==="
df -h / | tail -1
du -sh "$APP_DIR" 2>/dev/null | awk '{print "  .app: " $1}'

# 打包: 用 ditto 创建 zip（增量流式，不占内存）
# ditto 是 macOS 原生工具，完美处理 APFS + 硬链接 + 大文件
ZIP_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.zip"
DMG_SRC="$BUILD_DIR/dmg_src"
rm -rf "$DMG_SRC"
mkdir -p "$DMG_SRC"
mv "$APP_DIR" "$DMG_SRC/"
ln -sf /Applications "$DMG_SRC/Applications"

echo "  创建归档 (ditto)..."
APP_BUNDLE="$DMG_SRC/FaceFusion.app"
ditto -c -k --keepParent --noqtn --noacl "$APP_BUNDLE" "$ZIP_FILE" 2>&1 || {
    echo "  ditto 失败，尝试 tar.gz..."
    TAR_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.tar.gz"
    cd "$DMG_SRC"
    tar czf "$TAR_FILE" FaceFusion.app 2>&1 || {
        echo "  tar 也失败，输出原始 .app 目录"
        ls -la "$DMG_SRC/"
        exit 1
    }
}

echo "=== 最终空间 ==="
df -h / | tail -1
echo ""
echo "==================================================="
echo " 构建完成!"
if [ -f "$ZIP_FILE" ]; then
    echo " ZIP: $(ls -lh "$ZIP_FILE" | awk '{print $5}')"
fi
if [ -f "$TAR_FILE" ]; then
    echo " TAR: $(ls -lh "$TAR_FILE" | awk '{print $5}')"
fi
echo "==================================================="

echo ""
echo "=== 最终空间 ==="
df -h / | tail -1
echo "==================================================="
echo " 构建完成!"
ls -lh "$BUILD_DIR"/FaceFusion4.8* 2>/dev/null
echo "==================================================="
