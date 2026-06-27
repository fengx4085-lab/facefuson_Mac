#!/bin/bash
# ───────────────────────────────────────────────────────
# FaceFusion4.8 黄金定制版 — macOS 构建脚本
# 在 GitHub Actions macos-latest runner 上运行
#
# 核心策略：直接在挂载的稀疏磁盘镜像中构建 .app，避免 cp 和
# hdiutil -srcfolder 产生第二份副本。构建完成后分离镜像，转换
# 为压缩 DMG。整个过程只有一份数据。
# ───────────────────────────────────────────────────────
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORK_DIR/build"

echo "==================================================="
echo " FaceFusion4.8 DMG 构建"
echo " 工作目录: $WORK_DIR"
echo "==================================================="

# ── 估算 DMG 大小，创建稀疏镜像 ─────────────────────
# 先用 df 算当前可用空间，留 5 GB 余量
AVAIL_GB=$(df -g / | tail -1 | awk '{print $4}')
DMG_SIZE_GB=$(( AVAIL_GB - 5 ))
echo "  可用: ${AVAIL_GB} GiB → DMG 镜像: ${DMG_SIZE_GB} GiB"

DMG_SPARSE="$BUILD_DIR/build.sparseimage"
VOLUME="/Volumes/FaceFusionBuild"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

hdiutil create \
    -size "${DMG_SIZE_GB}g" \
    -fs "Case-sensitive APFS" \
    -type SPARSE \
    -volname "FaceFusionBuild" \
    "$DMG_SPARSE"

hdiutil attach "$DMG_SPARSE" -noverify -mountpoint "$VOLUME"
echo "  镜像已挂载于 $VOLUME"

# ── 在镜像内建立 .app 骨架 ────────────────────────────
APP_DIR="$VOLUME/FaceFusion.app"
RESOURCES="$APP_DIR/Contents/Resources"
MACOS="$APP_DIR/Contents/MacOS"
DMG_STAGING="$VOLUME/dmg_staging"

mkdir -p "$RESOURCES" "$MACOS"

# 清理函数：无论成功失败都要卸载
cleanup() {
    echo "  卸载镜像..."
    hdiutil detach "$VOLUME" -force 2>/dev/null || true
}
trap cleanup EXIT

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

# ══════════════════════════════════════════════════════
# Step 3: FaceFusion 源码 + 中文化
# ══════════════════════════════════════════════════════
echo "[3/8] 准备 FaceFusion 源码..."
cp -r "$WORK_DIR/facefusion-master" "$RESOURCES/facefusion"

echo "  应用中文化补丁..."
cp "$WORK_DIR/launcher/patches/locales_with_zh.py" "$RESOURCES/facefusion/facefusion/locales.py"

# ══════════════════════════════════════════════════════
# Step 4: 预下载 AI 模型
# ══════════════════════════════════════════════════════
echo "[4/8] 预下载 AI 模型..."
MODEL_DIR="$RESOURCES/facefusion/.assets/models"
CACHE_DIR="$WORK_DIR/facefusion-master/.assets"

if [ -d "$CACHE_DIR/models" ] && [ "$(ls -1 "$CACHE_DIR/models" 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "  检测到缓存模型 ($(du -sh "$CACHE_DIR/models" | cut -f1))，将跳过已下载文件"
fi

export PATH="$RESOURCES:$PATH"
cd "$RESOURCES/facefusion"
"$VENV_PYTHON" facefusion.py force-download
echo "  模型下载完成 → $(du -sh "$MODEL_DIR" | cut -f1)"

# 写回缓存，下次命中
mkdir -p "$CACHE_DIR"
cp -r "$MODEL_DIR" "$CACHE_DIR/"
echo "  模型已同步至缓存目录"

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
    --workpath "$VOLUME/pyi_build" \
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
# Step 8: 清理 → 组装 DMG staging → 卸载 → 创建 DMG
# ══════════════════════════════════════════════════════
echo "[8/8] 制作 DMG..."

# 清理一切可以删的
rm -rf /tmp/pyi_build "$BUILD_DIR/pyinstaller_dist"
rm -rf "$VOLUME/pyi_build"
find "$RESOURCES/venv" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$RESOURCES/facefusion" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
rm -rf "$RESOURCES/venv/share" 2>/dev/null || true
rm -rf /tmp/launcher.spec

echo "=== 镜像用量 ==="
df -h "$VOLUME" | tail -1
echo "=== Runner 剩余 ==="
df -h / | tail -1

# 准备 DMG staging（同文件系统内 mv = 重命名，不占额外空间）
mkdir -p "$DMG_STAGING"
mv "$APP_DIR" "$DMG_STAGING/"
ln -sf /Applications "$DMG_STAGING/Applications"

# 卸载镜像
trap - EXIT
echo "  分离镜像..."
hdiutil detach "$VOLUME" -force

# 从稀疏镜像转换为压缩 DMG —— 这是唯一的生产步骤
DMG_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.dmg"
ZIP_FILE="$BUILD_DIR/FaceFusion4.8-macOS-arm64.zip"

echo "=== 转换前空间 ==="
df -h / | tail -1
du -sh "$DMG_SPARSE" | awk '{print "  稀疏镜像: " $1}'

if hdiutil convert "$DMG_SPARSE" -format UDZO -imagekey zlib-level=9 -o "$DMG_FILE" 2>&1; then
    echo "  DMG 创建成功"
    ls -lh "$DMG_FILE"
    rm -f "$DMG_SPARSE"
else
    echo "  hdiutil convert 失败，回退为 zip"
    # 重新挂载，用 zip 打包
    hdiutil attach "$DMG_SPARSE" -noverify -mountpoint "$VOLUME" 2>/dev/null || true
    cd "$DMG_STAGING"
    zip -rq "$ZIP_FILE" .
    echo "  ZIP: $(ls -lh "$ZIP_FILE" | awk '{print $5}')"
fi

echo "=== 最终空间 ==="
df -h / | tail -1
echo ""
echo "==================================================="
echo " 构建完成!"
if [ -f "$DMG_FILE" ]; then
    ls -lh "$DMG_FILE"
elif [ -f "$ZIP_FILE" ]; then
    ls -lh "$ZIP_FILE"
fi
echo "==================================================="
