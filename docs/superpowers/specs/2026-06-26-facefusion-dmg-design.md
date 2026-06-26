# FaceFusion4.8 黄金定制版 macOS DMG 整合包 — 设计规范

## Context

用户希望将 FaceFusion（原版 3.6.1）封装为一个 macOS .dmg 一键安装包，命名为 **FaceFusion4.8 黄金定制版**。目标用户是零技术基础的普通用户，安装后双击即可使用，无需配置 Python、conda 或任何环境。

技术约束：
- 适配所有 Apple M 系列芯片（M1/M2/M3/M4/M5/Pro/Max/Ultra），自动利用 CoreML 加速
- AI 模型预置，完全离线可用
- FFmpeg 内置
- 无需代码签名
- 启动器使用 Python tkinter 方案
- 界面主题：极简暗黑工程风 — 纯黑背景 + 浅灰按钮 + 白色文字，无复杂装饰

---

## 一、整体架构

```
FaceFusion.app/
└── Contents/
    ├── MacOS/
    │   └── FaceFusionLauncher       # PyInstaller 编译的可执行文件
    ├── Resources/
    │   ├── python/                  # portable Python 3.12 (python-build-standalone)
    │   ├── venv/                    # 预装 pip 依赖
    │   ├── facefusion/             # FaceFusion 源码 + 补丁(.assets/models/ 预下载)
    │   ├── ffmpeg                  # ffmpeg arm64 静态二进制
    │   ├── curl                    # curl arm64 静态二进制
    │   ├── icon.icns              # 应用图标
    │   └── icon.png               # 启动器窗口图标
    └── Info.plist                 # macOS Bundle 清单
```

### 依赖关系

```
用户双击 .app
  └─→ MacOS/FaceFusionLauncher (tkinter 启动器窗口)
        └─→ 点击"开始换脸"
              ├─→ subprocess.Popen 启动 Resources/venv/bin/python
              │     └─→ facefusion.py run --open-browser
              │           ├─→ gradio WebUI 监听 127.0.0.1:7860
              │           └─→ 打印 "Running on local URL: http://127.0.0.1:7860"
              ├─→ 轮询 stdout，检测到 URL 后自动打开浏览器
              └─→ 点击"停止换脸" → process_manager.stop() → 优雅终止
```

---

## 二、启动器设计 (launcher.py)

### 2.1 窗口布局

```
┌───────────────────────────────────────────────────┐
│                                                   │
│                 FaceFusion                        │  ← 白字无衬线粗体, 居中
│              v4.8 黄金定制版                       │  ← 白字小号
│                                                   │
│                                                   │
│       ┌──────────────┐   ┌──────────────┐        │  ← 两按钮横向并排
│       │   开始换脸    │   │   停止换脸    │        │    浅灰底，深色字
│       └──────────────┘   └──────────────┘        │
│                                                   │
│  ┌────────────────────────────────────────────┐  │
│  │ [12:30:01] Installing prerequisites...     │  │  ← 浅灰半透明底
│  │ [12:30:02] Downloading models...           │  │    白色/浅灰等宽字体
│  │ [12:30:05] Server started at 127.0.0.1    │  │    密集英文代码风格
│  │ [12:30:05] Browser opened                  │  │
│  │ ...                                        │  │
│  └────────────────────────────────────────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘

窗口尺寸: 680 x 520 px, 固定不可缩放, 居中显示
```

### 2.2 界面样式

| 元素 | 样式 |
|------|------|
| 整体背景 | 纯黑 `#000000` |
| 标题 "FaceFusion" | 白色 `#FFFFFF`，24pt，Helvetica Bold，居中 |
| 副标题 "v4.8 黄金定制版" | 浅灰 `#AAAAAA`，12pt，Helvetica，居中 |
| 按钮背景 | 浅灰 `#3A3A3C`（macOS 原生控件灰） |
| 按钮文字 | 黑色 `#000000` 或深灰 `#1C1C1E`，14pt，居中 |
| 按钮 Hover | 背景变亮 `#4A4A4C` |
| 按钮圆角 | 8px，扁平无阴影 |
| 按钮尺寸 | 140 x 38 px，间距 20 px |
| 日志区背景 | 浅灰半透明 `rgba(60,60,67,0.3)` 或 `#1C1C1E` |
| 日志文字 | 浅灰 `#CCCCCC`，11pt，Menlo 等宽字体 |

### 2.3 交互行为

| 操作 | 行为 |
|------|------|
| 点击"开始换脸" | 按钮变灰(disabled)，启动 FaceFusion 子进程，日志区实时输出，自动打开浏览器 |
| 点击"停止换脸" | 发送 SIGTERM 终止子进程，按钮恢复可用 |
| 开始按钮 disabled 时 | 背景变暗 `#2A2A2C`，文字变 `#666666`，不可点击 |
| 停止按钮在未运行时 | 同样 disabled 状态 |
| 关闭窗口 (红X) | 窗口隐藏到 Dock，后台进程继续运行 |
| 点击 Dock 图标 | 窗口重新显示（deiconify + lift） |
| Dock 右键 → 退出 | 停止后台进程，清理临时文件，root.destroy() |
| 启动器窗口 | 使用系统原生标题栏（保留红绿灯），窗口居中，固定尺寸

### 2.4 启动流程细节

```
1. 显示窗口，日志打印 "FaceFusion4.8 启动中..."
2. 检查 Resources/ 下依赖完整性（python、venv、models、ffmpeg）
3. 设置环境变量：
   - PATH = Resources/:$PATH  (让 facefusion 找到 ffmpeg 和 curl)
   - 工作目录 cwd = Resources/facefusion/ (让模型从 .assets/ 加载)
4. 启动子进程：
   Resources/venv/bin/python Resources/facefusion/facefusion.py run --open-browser
5. 实时读取 stdout/stderr，前缀时间戳写入日志区
6. 检测到 "Running on local URL" → 日志打勾，调用 webbrowser.open()
7. 子进程退出时 → 按钮恢复，日志显示退出信息
```

---

## 三、FaceFusion 源码修改

### 3.1 中文化

将 Marspacecraft/facefusionchines 的 `wording.py` 合并到 `facefusion/facefusion/wording.py`，并在基础上补充完整翻译。

### 3.2 ffmpeg/curl 路径检测

`facefusion/core.py:94-106` 中 `pre_check()` 检查系统是否安装了 ffmpeg/curl。启动器启动子进程前将 `Resources/` 加入 PATH 环境变量，`shutil.which` 即可自动找到。源码无需修改。

### 3.3 模型路径

FaceFusion 默认将模型下载到项目根目录的 `.assets/models/` 子目录。启动子进程时将 `cwd` 设为 `Resources/facefusion/`，预下载的模型放在对应位置即可被加载。

### 3.4 跳过 install.py

直接使用预配置的 venv（pip install 所有依赖），不经过 install.py。启动时直接调用 `facefusion.py run --open-browser`。

### 3.5 conda 检查

`installer.py` 中有 conda 检查逻辑，但 `run` 命令不涉及 installer 模块，无需修改。

---

## 四、构建流程

### 4.1 Windows 开发阶段

在 Windows 上完成：
- [ ] 编写 `launcher.py`（tkinter 启动器）
- [ ] 编写 `build.sh`（macOS 构建脚本）
- [ ] 编写 `.github/workflows/build.yml`
- [ ] 准备 `Info.plist`
- [ ] 准备应用图标资源
- [ ] 在 Windows 本地可运行启动器 UI（不连 FaceFusion 后端）

### 4.2 GitHub Actions macOS Runner 构建

Workflow 触发条件：手动触发 (`workflow_dispatch`)。

```
Job: build-dmg
  runs-on: macos-latest  (Apple Silicon M-series runner)
  
  Steps:
  1. actions/checkout 拉取本项目代码
  2. 下载 portable Python 3.12 (arm64)
  3. 创建 venv 并安装 pip 依赖
  4. 克隆 facefusion 源码 + 应用我们的补丁
  5. 运行 force-download 预下载模型
  6. 下载 ffmpeg/curl 静态二进制
  7. 组装 .app Bundle 目录结构
  8. PyInstaller 编译 launcher.py → FaceFusionLauncher 可执行文件
  9. 整体 .app 可用性检查
  10. create-dmg 打包为 DMG
  11. 上传 Artifact
```

### 4.3 依赖清单

```
# pip 包 (来自 facefusion/requirements.txt)
gradio-rangeslider==0.0.8
gradio==5.44.1
numpy==2.2.1
onnx==1.21.0
onnxruntime==1.24.4         # Apple Silicon 自动启用 CoreML
opencv-python==4.13.0.92
tqdm==4.67.3
scipy==1.17.1

# 额外依赖（仅构建时）
pyinstaller                  # 编译 launcher.py → 可执行文件
```

### 4.4 产物体积预估

| 组件 | 体积 |
|------|------|
| portable Python 3.12 | ~80 MB |
| venv pip 包 | ~500 MB |
| FaceFusion 源码 | ~5 MB |
| AI 模型 (.assets) | ~2.5 GB |
| ffmpeg 静态二进制 | ~80 MB |
| curl 静态二进制 | ~5 MB |
| PyInstaller 启动器 | ~20 MB |
| **合计** | **~3.2 GB** |
| **DMG 压缩后** | **~2.0-2.5 GB** |

---

## 五、tkinter macOS 适配要点

### 5.1 窗口隐藏至 Dock

```python
# 关闭按钮 → 隐藏而非退出
root.protocol('WM_DELETE_WINDOW', hide_window)

def hide_window():
    root.withdraw()  # 隐藏窗口，进程继续

# 点击 Dock 图标 → 恢复窗口
root.createcommand('tk::mac::ReopenApplication', show_window)

def show_window():
    root.deiconify()  # 恢复窗口
    root.lift()       # 置前
```

### 5.2 Dock 右键菜单（退出）

```python
menubar = tk.Menu(root)
app_menu = tk.Menu(menubar, name='apple')
app_menu.add_command(label='退出 FaceFusion', command=quit_app)
menubar.add_cascade(menu=app_menu)
root.config(menu=menubar)

def quit_app():
    stop_backend()
    root.destroy()
```

### 5.3 窗口配置

```python
# 使用系统原生标题栏（保留红绿灯）
root.title("FaceFusion")
root.resizable(False, False)     # 固定尺寸
root.configure(bg='#000000')     # 纯黑背景

# 窗口居中
window_width, window_height = 680, 520
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
x = (screen_width - window_width) // 2
y = (screen_height - window_height) // 2
root.geometry(f'{window_width}x{window_height}+{x}+{y}')
```

---

## 六、Info.plist 配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FaceFusionLauncher</string>
    <key>CFBundleIdentifier</key>
    <string>com.facefusion.gold-4-8</string>
    <key>CFBundleName</key>
    <string>FaceFusion4.8</string>
    <key>CFBundleDisplayName</key>
    <string>FaceFusion4.8 黄金定制版</string>
    <key>CFBundleVersion</key>
    <string>4.8.0</string>
    <key>CFBundleShortVersionString</key>
    <string>4.8</string>
    <key>CFBundleIconFile</key>
    <string>icon.icns</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
```

---

## 七、DMG 打包

```bash
create-dmg \
  --volname "FaceFusion4.8" \
  --volicon "assets/dmg-icon.icns" \
  --background "assets/dmg-bg.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 100 \
  --icon "FaceFusion.app" 180 170 \
  --hide-extension "FaceFusion.app" \
  --app-drop-link 480 170 \
  "FaceFusion4.8-macOS-arm64.dmg" \
  dmg_contents/
```

---

## 八、验证清单

- [ ] DMG 在干净 macOS（无 conda/Python）上双击安装
- [ ] 拖拽到 Applications 后双击启动
- [ ] 启动器窗口正确显示极简暗黑风格
- [ ] 标题居中显示 "FaceFusion" + "v4.8 黄金定制版"
- [ ] 两个按钮水平并排，"开始换脸"和"停止换脸"
- [ ] 点击"开始换脸"启动后端
- [ ] 浏览器自动打开 WebUI
- [ ] 日志实时滚动
- [ ] 点击"停止换脸"停止后端
- [ ] 关闭窗口隐藏至 Dock
- [ ] 点击 Dock 图标恢复窗口
- [ ] 右键 Dock 退出完整清理
- [ ] 在 M1/M2/M3 芯片上分别验证 CoreML 加速正常工作
- [ ] 图片换脸功能正常
- [ ] 视频换脸功能正常
