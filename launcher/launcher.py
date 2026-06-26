#!/usr/bin/env python3
"""
FaceFusion4.8 黄金定制版 — macOS 桌面启动器
极简暗黑功能主义风格
"""

import os
import sys
import json
import time
import signal
import shutil
import socket
import struct
import platform
import tempfile
import webbrowser
import subprocess
import threading
from datetime import datetime
from pathlib import Path

# ── tkinter ──────────────────────────────────────────────
import tkinter as tk
from tkinter import ttk
from tkinter import scrolledtext

# ── 全局状态 ────────────────────────────────────────────
APP_VERSION = "4.8"
APP_NAME = "FaceFusion4.8 黄金定制版"
WINDOW_WIDTH = 680
WINDOW_HEIGHT = 520

_process: subprocess.Popen | None = None
_log_thread: threading.Thread | None = None
_is_running = False

# ── 颜色常量 ────────────────────────────────────────────
BG         = "#000000"   # 纯黑
FG_TITLE   = "#FFFFFF"   # 白
FG_SUBTITLE = "#AAAAAA"  # 浅灰
BTN_BG     = "#3A3A3C"   # 浅灰按钮
BTN_FG     = "#FFFFFF"   # 按钮白字
BTN_DIS_BG = "#2A2A2C"   # 禁用按钮背景(暗)
BTN_DIS_FG = "#666666"   # 禁用按钮文字(暗)
LOG_BG     = "#1C1C1E"   # 日志区深色背景
LOG_FG     = "#CCCCCC"   # 浅灰等宽字体
LOG_FN     = ("Menlo", "Consolas", "Courier New")


# ═══════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════

def get_app_path() -> Path:
    """找到 .app/Contents 的根路径"""
    # macOS: 从可执行文件位置反推
    if getattr(sys, 'frozen', False):
        executable = Path(sys.executable)
        return executable.parent.parent  # MacOS/ → Contents/, Contents/ → .app/
    # 开发模式：直接在当前目录运行
    return Path(__file__).resolve().parent

def get_resources_path() -> Path:
    """Resources 目录"""
    if getattr(sys, 'frozen', False):
        return get_app_path() / "Resources"
    return get_app_path()

def get_facefusion_path() -> Path:
    """FaceFusion 源码目录"""
    return get_resources_path() / "facefusion"

def get_venv_python() -> Path:
    """venv 中的 Python 可执行文件"""
    return get_resources_path() / "venv" / "bin" / "python3"

def get_backend_pid_file() -> Path:
    return Path(tempfile.gettempdir()) / "facefusion_launcher.pid"

def timestamp() -> str:
    return datetime.now().strftime("%H:%M:%S")

def is_port_in_use(port: int = 7860) -> bool:
    """检查端口是否被占用"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.5)
        result = sock.connect_ex(('127.0.0.1', port))
        sock.close()
        return result == 0
    except Exception:
        return False

def resolve_ffmpeg_path() -> str | None:
    """查找 ffmpeg 路径"""
    # 优先使用 Resources 内的
    ffmpeg_path = get_resources_path() / "ffmpeg"
    if ffmpeg_path.exists():
        return str(ffmpeg_path)
    # fallback 系统安装的
    system_ffmpeg = shutil.which("ffmpeg")
    return system_ffmpeg

def resolve_curl_path() -> str | None:
    curl_path = get_resources_path() / "curl"
    if curl_path.exists():
        return str(curl_path)
    system_curl = shutil.which("curl")
    return system_curl


# ═══════════════════════════════════════════════════════════
# 进程管理
# ═══════════════════════════════════════════════════════════

def build_environment() -> dict:
    """构建子进程环境变量"""
    env = os.environ.copy()
    resources = str(get_resources_path())

    # 修改 PATH，使 ffmpeg、curl 可被 shutil.which 找到
    env["PATH"] = f"{resources}:{env.get('PATH', '')}"

    # Python 相关
    env["PYTHONUNBUFFERED"] = "1"

    # 跳过 Gradio 遥测
    env["GRADIO_ANALYTICS_ENABLED"] = "0"

    return env

def start_facefusion(log_callback):
    """启动 FaceFusion 子进程"""
    global _process, _is_running

    ffmpeg = resolve_ffmpeg_path()
    curl = resolve_curl_path()

    # 环境检查
    python = get_venv_python()
    cwd = get_facefusion_path()

    log_callback(f"[{timestamp()}] 环境检查中...")
    log_callback(f"[{timestamp()}]   Python: {python} {'✓' if python.exists() else '✗ 缺失'}")

    if not python.exists():
        log_callback(f"[{timestamp()}] ✗ 错误: Python 运行时未找到，请重新安装")
        return

    log_callback(f"[{timestamp()}]   FFmpeg: {ffmpeg} {'✓' if ffmpeg and Path(ffmpeg).exists() else '✗ 缺失'}")
    log_callback(f"[{timestamp()}]   Curl: {curl} {'✓' if curl and Path(curl).exists() else '✗ 缺失'}")
    log_callback(f"[{timestamp()}]   工作目录: {cwd}")

    if not (cwd / "facefusion.py").exists():
        log_callback(f"[{timestamp()}] ✗ 错误: facefusion.py 未找到")
        return

    # 构建启动命令
    env = build_environment()
    cmd = [str(python), "facefusion.py", "run", "--open-browser"]

    log_callback(f"[{timestamp()}] 正在启动 FaceFusion 服务...")

    try:
        _process = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            bufsize=1,
            universal_newlines=True,
            preexec_fn=os.setsid if platform.system() != "Windows" else None,
        )
        _is_running = True

        log_callback(f"[{timestamp()}] 服务进程 PID: {_process.pid}")

        # 读取输出
        url_detected = False
        for line in iter(_process.stdout.readline, ""):
            if not _is_running:
                break
            stripped = line.rstrip()
            if stripped:
                log_callback(f"[{timestamp()}] {stripped}")

            # 检测 Gradio URL
            if "Running on local URL" in stripped and not url_detected:
                url_detected = True
                # 打开浏览器
                webbrowser.open("http://127.0.0.1:7860")
                log_callback(f"[{timestamp()}] ✓ 浏览器已打开")

        _process.wait()
        rc = _process.returncode
        if rc == 0:
            log_callback(f"[{timestamp()}] 服务已正常退出")
        elif _is_running:
            log_callback(f"[{timestamp()}] 服务异常退出，返回码: {rc}")

    except FileNotFoundError:
        log_callback(f"[{timestamp()}] ✗ 错误: 找不到 Python 解释器")
    except Exception as e:
        log_callback(f"[{timestamp()}] ✗ 错误: {e}")
    finally:
        _process = None
        _is_running = False

def stop_facefusion(log_callback):
    """停止 FaceFusion 进程"""
    global _process, _is_running

    if _process is None or not _is_running:
        log_callback(f"[{timestamp()}] 没有正在运行的服务")
        return

    log_callback(f"[{timestamp()}] 正在停止服务...")
    _is_running = False

    try:
        if platform.system() == "Windows":
            _process.terminate()
        else:
            # 发送 SIGTERM 给整个进程组
            os.killpg(os.getpgid(_process.pid), signal.SIGTERM)

        # 等待 10 秒后强制终止
        try:
            _process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            _process.kill()
            _process.wait()

        log_callback(f"[{timestamp()}] 服务已停止")
    except Exception as e:
        log_callback(f"[{timestamp()}] 停止服务时出错: {e}")
    finally:
        _process = None


# ═══════════════════════════════════════════════════════════
# 启动器 GUI
# ═══════════════════════════════════════════════════════════

class LauncherApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self._setup_window()
        self._build_ui()

    # ── Window ────────────────────────────────────────

    def _setup_window(self):
        root = self.root
        root.title(APP_NAME)
        root.configure(bg=BG)

        # 固定尺寸，不可缩放
        root.resizable(False, False)

        # 居中
        x = (root.winfo_screenwidth() - WINDOW_WIDTH) // 2
        y = (root.winfo_screenheight() - WINDOW_HEIGHT) // 2
        root.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}+{x}+{y}")

        # 关闭 → 隐藏到 Dock
        root.protocol("WM_DELETE_WINDOW", self.hide_window)

        # 最小尺寸确保布局完整
        root.minsize(WINDOW_WIDTH, WINDOW_HEIGHT)

        # macOS Dock 点击恢复
        self._setup_mac_menu()

    def _setup_mac_menu(self):
        """设置 macOS Application 菜单 (Dock 右键退出)"""
        if platform.system() != "Darwin":
            return
        try:
            root = self.root
            menubar = tk.Menu(root)
            app_menu = tk.Menu(menubar, name="apple")
            app_menu.add_command(label=f"关于 {APP_NAME}", command=self._about)
            app_menu.add_separator()
            app_menu.add_command(label="退出 FaceFusion", command=self.quit_app)
            menubar.add_cascade(menu=app_menu)
            root.config(menu=menubar)

            # 注册 Dock 恢复
            root.createcommand("tk::mac::ReopenApplication", self.show_window)
        except Exception:
            pass

    def _about(self):
        self.log(f"[{timestamp()}] {APP_NAME}")
        self.log(f"[{timestamp()}] 基于 FaceFusion 3.6.1，预置 CoreML 加速")

    # ── UI 构建 ───────────────────────────────────────

    def _build_ui(self):
        root = self.root

        # 顶部留白
        spacer_top = tk.Frame(root, bg=BG, height=60)
        spacer_top.pack(fill=tk.X)
        spacer_top.pack_propagate(False)

        # 标题
        title = tk.Label(
            root,
            text="FaceFusion",
            fg=FG_TITLE,
            bg=BG,
            font=("Helvetica", 26, "bold"),
        )
        title.pack()

        # 副标题（小间距）
        subtitle = tk.Label(
            root,
            text=f"v{APP_VERSION} 黄金定制版",
            fg=FG_SUBTITLE,
            bg=BG,
            font=("Helvetica", 12),
        )
        subtitle.pack(pady=(4, 0))

        # 按钮区
        btn_spacer = tk.Frame(root, bg=BG, height=40)
        btn_spacer.pack(fill=tk.X)
        btn_spacer.pack_propagate(False)

        btn_frame = tk.Frame(root, bg=BG)
        btn_frame.pack()

        self.btn_start = tk.Button(
            btn_frame,
            text="开始换脸",
            bg=BTN_BG,
            fg=BTN_FG,
            activebackground="#4A4A4C",
            activeforeground="#FFFFFF",
            relief=tk.FLAT,
            bd=0,
            padx=24,
            pady=8,
            font=("Helvetica", 13),
            width=12,
            cursor="pointinghand",
            command=self.on_start,
        )
        self.btn_start.pack(side=tk.LEFT, padx=(0, 10))

        self.btn_stop = tk.Button(
            btn_frame,
            text="停止换脸",
            bg=BTN_DIS_BG,
            fg=BTN_DIS_FG,
            activebackground="#4A4A4C",
            activeforeground="#FFFFFF",
            relief=tk.FLAT,
            bd=0,
            padx=24,
            pady=8,
            font=("Helvetica", 13),
            width=12,
            state=tk.DISABLED,
            cursor="pointinghand",
            command=self.on_stop,
        )
        self.btn_stop.pack(side=tk.LEFT, padx=(10, 0))

        # 日志区留白
        log_spacer = tk.Frame(root, bg=BG, height=30)
        log_spacer.pack(fill=tk.X)
        log_spacer.pack_propagate(False)

        # 日志外层容器
        log_container = tk.Frame(root, bg=LOG_BG)
        log_container.pack(fill=tk.BOTH, expand=True, padx=40, pady=(0, 40))

        self.log_area = tk.Text(
            log_container,
            bg=LOG_BG,
            fg=LOG_FG,
            insertbackground=LOG_FG,
            font=LOG_FN + (10,),
            wrap=tk.WORD,
            relief=tk.FLAT,
            bd=0,
            padx=12,
            pady=8,
            state=tk.DISABLED,
        )
        self.log_area.pack(fill=tk.BOTH, expand=True)

        self.log(f"[{timestamp()}] {APP_NAME} 已就绪")

    # ── 日志 ──────────────────────────────────────────

    def log(self, msg: str):
        self.log_area.configure(state=tk.NORMAL)
        self.log_area.insert(tk.END, msg + "\n")
        self.log_area.see(tk.END)  # 自动滚动
        self.log_area.configure(state=tk.DISABLED)

    # ── 按钮状态 ──────────────────────────────────────

    def _set_btn_start_enabled(self, enabled: bool):
        if enabled:
            self.btn_start.configure(
                bg=BTN_BG, fg=BTN_FG, state=tk.NORMAL, cursor="pointinghand"
            )
        else:
            self.btn_start.configure(
                bg=BTN_DIS_BG, fg=BTN_DIS_FG, state=tk.DISABLED
            )

    def _set_btn_stop_enabled(self, enabled: bool):
        if enabled:
            self.btn_stop.configure(
                bg=BTN_BG, fg=BTN_FG, state=tk.NORMAL, cursor="pointinghand"
            )
        else:
            self.btn_stop.configure(
                bg=BTN_DIS_BG, fg=BTN_DIS_FG, state=tk.DISABLED
            )

    # ── 隐藏/恢复 ─────────────────────────────────────

    def hide_window(self):
        self.root.withdraw()
        self.log(f"[{timestamp()}] 窗口已隐藏至 Dock，后台服务继续运行")

    def show_window(self):
        self.root.deiconify()
        self.root.lift()
        self.root.focus_force()

    # ── 开始/停止 ─────────────────────────────────────

    def on_start(self):
        global _is_running, _log_thread

        if _is_running:
            self.log(f"[{timestamp()}] 服务已在运行中")
            return

        self._set_btn_start_enabled(False)
        self._set_btn_stop_enabled(True)

        _log_thread = threading.Thread(
            target=start_facefusion, args=(self.log,), daemon=True
        )
        _log_thread.start()

        # 定期检查进程状态以恢复按钮
        self.root.after(500, self._check_process)

    def on_stop(self):
        global _is_running

        if not _is_running:
            self.log(f"[{timestamp()}] 服务未在运行")
            return

        self._set_btn_stop_enabled(False)

        stop_facefusion(self.log)

        self.root.after(500, self._check_process)

    def _check_process(self):
        global _process, _is_running

        if _process is not None and _process.poll() is not None:
            # 进程已退出
            _is_running = False
            _process = None

        if not _is_running:
            self._set_btn_start_enabled(True)
            self._set_btn_stop_enabled(False)
        else:
            self.root.after(500, self._check_process)

    # ── 退出 ──────────────────────────────────────────

    def quit_app(self):
        global _is_running, _process

        self.log(f"[{timestamp()}] 正在退出...")

        if _is_running and _process:
            stop_facefusion(self.log)

        self.root.destroy()
        sys.exit(0)


# ═══════════════════════════════════════════════════════════
# 入口
# ═══════════════════════════════════════════════════════════

def main():
    root = tk.Tk()
    app = LauncherApp(root)

    # 尝试设置 Dock 图标 (macOS only)
    if platform.system() == "Darwin":
        try:
            icon_path = get_resources_path() / "icon.png"
            if icon_path.exists():
                # 用 tk 原生方式设 dock 图标
                img = tk.PhotoImage(file=str(icon_path))
                root.iconphoto(True, img)
        except Exception:
            pass

    root.mainloop()
    sys.exit(0)


if __name__ == "__main__":
    main()
