#!/usr/bin/env python3
"""
FaceFusion 3.6.1 中文化补丁
在 facefusion/facefusion/locales.py 中添加 'zh' (中文) 语言条目
"""

import re
import sys
from pathlib import Path

# ── 中文翻译映射 (英文 key → 中文翻译) ────────────────────
# 基于 facefusionchines/wording.py 适配至 3.6.1

ZH_TRANSLATIONS = {
    # ── 系统和安装 ──
    "conda_not_activated": "Conda 未激活",
    "python_not_supported": "Python 版本不支持，请升级到 {version} 或更高版本",
    "curl_not_installed": "CURL 未安装",
    "ffmpeg_not_installed": "FFmpeg 未安装",
    "creating_temp": "正在创建临时资源",
    "extracting_frames": "正在提取分辨率为 {resolution} 且每秒 {fps} 帧的视频帧",
    "extracting_frames_succeeded": "提取帧成功",
    "extracting_frames_failed": "提取帧失败",
    "analysing": "分析中",
    "extracting": "提取中",
    "streaming": "串流中",
    "processing": "处理中",
    "merging": "合并中",
    "downloading": "下载中",
    "temp_frames_not_found": "临时帧未找到",
    "copying_image": "正在复制分辨率为 {resolution} 的图像",
    "copying_image_succeeded": "复制图像成功",
    "copying_image_failed": "复制图像失败",
    "finalizing_image": "正在定稿分辨率为 {resolution} 的图像",
    "finalizing_image_succeeded": "定稿图像成功",
    "finalizing_image_skipped": "跳过定稿图像",
    "merging_video": "正在合并分辨率为 {resolution} 且每秒 {fps} 帧的视频",
    "merging_video_succeeded": "合并视频成功",
    "merging_video_failed": "合并视频失败",
    "skipping_audio": "正在跳过音频",
    "replacing_audio_succeeded": "替换音频成功",
    "replacing_audio_skipped": "跳过替换音频",
    "restoring_audio_succeeded": "恢复音频成功",
    "restoring_audio_skipped": "跳过恢复音频",
    "clearing_temp": "正在清理临时资源",
    "processing_stopped": "处理已停止",
    "processing_image_succeeded": "图像处理成功，耗时 {seconds} 秒",
    "processing_image_failed": "图像处理失败",
    "processing_video_succeeded": "视频处理成功，耗时 {seconds} 秒",
    "processing_video_failed": "视频处理失败",
    "choose_image_source": "为源文件选择一张图像",
    "choose_audio_source": "为源文件选择一段音频",
    "choose_video_target": "为目标文件选择一个视频",
    "choose_image_or_video_target": "为目标文件选择一个图像或视频",
    "specify_image_or_video_output": "指定输出图像或视频的文件夹",
    "match_target_and_output_extension": "匹配目标文件和输出的扩展名",
    "no_source_face_detected": "未检测到源文件中的面部",
    "processor_not_loaded": "无法加载处理器 {processor}",
    "processor_not_implemented": "处理器 {processor} 未正确实现",
    "ui_layout_not_loaded": "无法加载 UI 布局 {ui_layout}",
    "ui_layout_not_implemented": "UI 布局 {ui_layout} 未正确实现",
    "stream_not_loaded": "无法加载流 {stream_mode}",
    "stream_not_supported": "不支持该串流模式",

    # ── 任务管理 ──
    "job_created": "任务 {job_id} 已创建",
    "job_not_created": "任务 {job_id} 创建失败",
    "job_submitted": "任务 {job_id} 已提交",
    "job_not_submitted": "任务 {job_id} 提交失败",
    "job_all_submitted": "全部任务已提交",
    "job_all_not_submitted": "全部任务提交失败",
    "job_deleted": "任务 {job_id} 已删除",
    "job_not_deleted": "任务 {job_id} 删除失败",
    "job_all_deleted": "全部任务已删除",
    "job_all_not_deleted": "全部任务删除失败",
    "job_step_added": "步骤已添加至任务 {job_id}",
    "job_step_not_added": "步骤添加至任务 {job_id} 失败",
    "job_remix_step_added": "步骤 {step_index} 已从任务 {job_id} 中混音",
    "job_remix_step_not_added": "步骤 {step_index} 从任务 {job_id} 中混音失败",
    "job_step_inserted": "步骤 {step_index} 已插入任务 {job_id}",
    "job_step_not_inserted": "步骤 {step_index} 插入任务 {job_id} 失败",
    "job_step_removed": "步骤 {step_index} 已从任务 {job_id} 中移除",
    "job_step_not_removed": "步骤 {step_index} 从任务 {job_id} 中移除失败",
    "running_job": "正在运行队列中的任务 {job_id}",
    "running_jobs": "正在运行所有队列中的任务",
    "retrying_job": "正在重试失败的任务 {job_id}",
    "retrying_jobs": "正在重试所有失败的任务",
    "processing_job_succeeded": "任务 {job_id} 处理成功",
    "processing_jobs_succeeded": "所有任务处理成功",
    "processing_job_failed": "任务 {job_id} 处理失败",
    "processing_jobs_failed": "所有任务处理失败",
    "processing_step": "正在处理第 {step_current} 步，共 {step_total} 步",

    # ── 验证 ──
    "validating_hash_succeeded": "验证哈希文件 {hash_file_name} 成功",
    "validating_hash_failed": "验证哈希文件 {hash_file_name} 失败",
    "validating_source_succeeded": "验证源文件 {source_file_name} 成功",
    "validating_source_failed": "验证源文件 {source_file_name} 失败",
    "deleting_corrupt_source": "正在删除损坏的源文件 {source_file_name}",
    "loading_model_succeeded": "模型 {model_name} 加载成功，耗时 {seconds} 秒",
    "loading_model_failed": "模型 {model_name} 加载失败",

    # ── 时间 ──
    "time_ago_now": "刚刚",
    "time_ago_minutes": "{minutes} 分钟前",
    "time_ago_hours": "{hours} 小时 {minutes} 分钟前",
    "time_ago_days": "{days} 天 {hours} 小时 {minutes} 分钟前",

    # ── 标点 ──
    "point": "。",
    "comma": "，",
    "colon": "：",
    "question_mark": "？",
    "exclamation_mark": "！",

    # ── about ──
    "fund": "资助 AI 工作站",
    "subscribe": "成为会员",
    "join": "加入我们的社区",

    # ── help ──
    "install_dependency": "选择要安装的 {dependency} 变体",
    "skip_conda": "跳过 conda 环境检查",
    "config_path": "选择用于覆盖默认值的配置文件",
    "temp_path": "指定临时资源目录",
    "jobs_path": "指定任务存储目录",
    "source_paths": "选择图像或音频路径",
    "target_path": "选择图像或视频路径",
    "output_path": "指定输出图像或视频的文件夹",
    "face_detector_model": "选择负责检测面部的模型",
    "face_detector_size": "指定提供给面部检测器的帧尺寸",
    "face_detector_margin": "为帧应用上、右、下、左边距",
    "face_detector_angles": "指定在检测面部前旋转帧的角度",
    "face_detector_score": "基于置信度分数过滤检测到的面部",
    "face_landmarker_model": "选择负责检测面部关键点的模型",
    "face_landmarker_score": "基于置信度分数过滤检测到的面部关键点",
    "face_selector_mode": "使用基于参考的跟踪或简单匹配",
    "face_selector_order": "指定检测到的面部的顺序",
    "face_selector_age_start": "基于起始年龄过滤检测到的面部",
    "face_selector_age_end": "基于结束年龄过滤检测到的面部",
    "face_selector_gender": "基于性别过滤检测到的面部",
    "face_selector_race": "基于种族过滤检测到的面部",
    "reference_face_position": "指定用于创建参考面部的位置",
    "reference_face_distance": "指定参考面部和目标面部之间的相似度",
    "reference_frame_number": "指定用于创建参考面部的帧",
    "face_occluder_model": "选择负责遮挡掩膜的模型",
    "face_parser_model": "选择负责区域掩膜的模型",
    "face_mask_types": "混合不同的面部掩膜类型 (选项: {choices})",
    "face_mask_areas": "选择用于区域掩膜的项 (选项: {choices})",
    "face_mask_regions": "选择用于区域掩膜的项 (选项: {choices})",
    "face_mask_blur": "指定应用于框掩膜的模糊程度",
    "face_mask_padding": "为框掩膜应用上、右、下、左内边距",
    "voice_extractor_model": "选择负责提取语音的模型",
    "trim_frame_start": "指定目标视频的起始帧",
    "trim_frame_end": "指定目标视频的结束帧",
    "temp_frame_format": "指定临时资源格式",
    "keep_temp": "处理后保留临时资源",
    "output_image_quality": "指定图像质量（对应图像压缩率）",
    "output_image_scale": "基于目标图像指定图像缩放比例",
    "output_audio_encoder": "指定用于音频的编码器",
    "output_audio_quality": "指定音频质量（对应音频压缩率）",
    "output_audio_volume": "基于目标视频指定音频音量",
    "output_video_encoder": "指定用于视频的编码器",
    "output_video_preset": "平衡视频处理速度与文件体积",
    "output_video_quality": "指定视频质量（对应视频压缩率）",
    "output_video_scale": "基于目标视频指定视频缩放比例",
    "output_video_fps": "基于目标视频指定视频帧率",
    "processors": "加载单个或多个处理器 (选项: {choices}, ...)",
    "open_browser": "程序就绪后自动打开浏览器",
    "ui_layouts": "启动单个或多个 UI 布局 (选项: {choices}, ...)",
    "ui_workflow": "选择 UI 工作流",
    "download_providers": "使用不同的下载提供者 (选项: {choices}, ...)",
    "download_scope": "指定下载范围",
    "benchmark_mode": "选择基准测试模式",
    "benchmark_resolutions": "选择基准测试分辨率 (选项: {choices}, ...)",
    "benchmark_cycle_count": "指定每个基准测试的循环次数",
    "execution_device_ids": "指定用于处理的设备 ID",
    "execution_providers": "使用不同的推理提供者 (选项: {choices}, ...)",
    "execution_thread_count": "指定处理时的并行线程数",
    "video_memory_strategy": "平衡快速处理和低 VRAM 占用",
    "system_memory_limit": "限制处理时可用的 RAM",
    "log_level": "调整终端显示的信息严重程度",
    "halt_on_error": "遇到错误时停止程序",
    "run": "运行程序",
    "headless_run": "无界面模式运行",
    "batch_run": "批量模式运行",
    "force_download": "强制自动下载并退出",
    "benchmark": "基准测试",
    "job_id": "指定任务 ID",
    "job_status": "指定任务状态",
    "step_index": "指定步骤索引",
    "job_list": "按状态列出任务",
    "job_create": "创建草稿任务",
    "job_submit": "提交草稿任务至队列",
    "job_submit_all": "提交所有草稿任务至队列",
    "job_delete": "删除草稿、已排队、失败或已完成的任务",
    "job_delete_all": "删除所有草稿、已排队、失败和已完成的任务",
    "job_add_step": "为草稿任务添加步骤",
    "job_remix_step": "从草稿任务中混音上一步",
    "job_insert_step": "为草稿任务插入步骤",
    "job_remove_step": "从草稿任务中移除步骤",
    "job_run": "运行队列中的任务",
    "job_run_all": "运行所有队列中的任务",
    "job_retry": "重试失败的任务",
    "job_retry_all": "重试所有失败的任务",
    "source_pattern": "选择图像或音频的匹配模式",
    "target_pattern": "选择图像或视频的匹配模式",
    "output_pattern": "指定图像或视频的匹配模式",
    "background-remover-model": "选择负责移除背景的模型",
    "background-remover-color": "为背景应用红、绿、蓝和透明通道值",
    "face_editor_model": "选择负责编辑面部的模型",
    "face_editor_eyebrow_direction": "指定眉毛方向",
    "face_editor_eye_gaze_horizontal": "指定水平眼视线",
    "face_editor_eye_gaze_vertical": "指定垂直眼视线",
    "face_editor_eye_open_ratio": "指定睁眼比例",
    "face_editor_lip_open_ratio": "指定嘴唇张开比例",
    "face_editor_mouth_grim": "指定嘴角方向",
    "face_editor_mouth_pout": "指定嘴唇突出程度",
    "face_editor_mouth_purse": "指定嘴唇闭合程度",
    "face_editor_mouth_smile": "指定微笑程度",
    "face_editor_head_pitch": "指定头部俯仰角度",
    "face_editor_head_yaw": "指定头部偏摆角度",
    "face_editor_head_roll": "指定头部旋转角度",

    # ── UI 组件标签 ──
    "apply_button": "应用",
    "benchmark_mode_dropdown": "基准模式",
    "benchmark_cycle_count_slider": "基准循环次数",
    "benchmark_resolutions_checkbox_group": "基准分辨率",
    "clear_button": "清除",
    "common_options_checkbox_group": "通用选项",
    "download_providers_checkbox_group": "下载提供者",
    "execution_providers_checkbox_group": "推理执行提供者",
    "execution_thread_count_slider": "执行线程数",
    "face_detector_angles_checkbox_group": "面部检测角度",
    "face_detector_model_dropdown": "面部检测模型",
    "face_detector_margin_slider": "面部检测边距",
    "face_detector_score_slider": "面部检测分数",
    "face_detector_size_dropdown": "面部检测尺寸",
    "face_landmarker_model_dropdown": "面部关键点模型",
    "face_landmarker_score_slider": "面部关键点分数",
    "face_mask_blur_slider": "面部掩膜模糊",
    "face_mask_padding_bottom_slider": "面部掩膜底部内边距",
    "face_mask_padding_left_slider": "面部掩膜左侧内边距",
    "face_mask_padding_right_slider": "面部掩膜右侧内边距",
    "face_mask_padding_top_slider": "面部掩膜顶部内边距",
    "face_mask_areas_checkbox_group": "面部掩膜区域",
    "face_mask_regions_checkbox_group": "面部掩膜部位",
    "face_mask_types_checkbox_group": "面部掩膜类型",
    "face_selector_age_range_slider": "面部选择年龄范围",
    "face_selector_gender_dropdown": "面部选择性别",
    "face_selector_mode_dropdown": "面部选择模式",
    "face_selector_order_dropdown": "面部选择排序",
    "face_selector_race_dropdown": "面部选择种族",
    "face_occluder_model_dropdown": "面部遮挡模型",
    "face_parser_model_dropdown": "面部分析模型",
    "voice_extractor_model_dropdown": "语音提取模型",
    "job_list_status_checkbox_group": "任务状态",
    "job_manager_job_action_dropdown": "任务操作",
    "job_manager_job_id_dropdown": "任务 ID",
    "job_manager_step_index_dropdown": "步骤索引",
    "job_runner_job_action_dropdown": "任务执行操作",
    "job_runner_job_id_dropdown": "任务执行 ID",
    "log_level_dropdown": "日志级别",
    "output_audio_encoder_dropdown": "输出音频编码器",
    "output_audio_quality_slider": "输出音频质量",
    "output_audio_volume_slider": "输出音频音量",
    "output_image_or_video": "输出结果",
    "output_image_quality_slider": "输出图像质量",
    "output_image_scale_slider": "输出图像缩放",
    "output_path_textbox": "输出路径",
    "output_video_encoder_dropdown": "输出视频编码器",
    "output_video_fps_slider": "输出视频帧率",
    "output_video_preset_dropdown": "输出视频预设",
    "output_video_quality_slider": "输出视频质量",
    "output_video_scale_slider": "输出视频缩放",
    "preview_frame_slider": "预览帧",
    "preview_image": "预览",
    "preview_mode_dropdown": "预览模式",
    "preview_resolution_dropdown": "预览分辨率",
    "processors_checkbox_group": "处理器",
    "reference_face_distance_slider": "参考面部距离",
    "reference_face_gallery": "参考面部",
    "refresh_button": "刷新",
    "source_file": "源文件",
    "start_button": "开始",
    "stop_button": "停止",
    "system_memory_limit_slider": "系统内存限制",
    "target_file": "目标文件",
    "temp_frame_format_dropdown": "临时帧格式",
    "terminal_textbox": "终端",
    "trim_frame_slider": "裁剪帧",
    "ui_workflow": "UI 工作流",
    "video_memory_strategy_dropdown": "显存策略",
    "webcam_fps_slider": "摄像头帧率",
    "webcam_image": "摄像头画面",
    "webcam_device_id_dropdown": "摄像头设备 ID",
    "webcam_mode_radio": "摄像头模式",
    "webcam_resolution_dropdown": "摄像头分辨率",
}


def build_nested_dict(flat_dict: dict) -> dict:
    """
    将扁平化的翻译 key → 值 结构重建为 FaceFusion 的嵌套结构：
    - 顶层通用 key
    - 'help' 子字典 (install_dependency, skip_conda, ...)
    - 'about' 子字典 (fund, subscribe, join)
    - 'uis' 子字典 (apply_button, start_button, ...)
    """
    help_keys = {
        "install_dependency", "skip_conda", "config_path", "temp_path",
        "jobs_path", "source_paths", "target_path", "output_path",
        "face_detector_model", "face_detector_size", "face_detector_margin",
        "face_detector_angles", "face_detector_score", "face_landmarker_model",
        "face_landmarker_score", "face_selector_mode", "face_selector_order",
        "face_selector_age_start", "face_selector_age_end",
        "face_selector_gender", "face_selector_race",
        "reference_face_position", "reference_face_distance",
        "reference_frame_number", "face_occluder_model", "face_parser_model",
        "face_mask_types", "face_mask_areas", "face_mask_regions",
        "face_mask_blur", "face_mask_padding", "voice_extractor_model",
        "trim_frame_start", "trim_frame_end", "temp_frame_format",
        "keep_temp", "output_image_quality", "output_image_scale",
        "output_audio_encoder", "output_audio_quality", "output_audio_volume",
        "output_video_encoder", "output_video_preset", "output_video_quality",
        "output_video_scale", "output_video_fps", "processors",
        "open_browser", "ui_layouts", "ui_workflow", "download_providers",
        "download_scope", "benchmark_mode", "benchmark_resolutions",
        "benchmark_cycle_count", "execution_device_ids", "execution_providers",
        "execution_thread_count", "video_memory_strategy",
        "system_memory_limit", "log_level", "halt_on_error", "run",
        "headless_run", "batch_run", "force_download", "benchmark",
        "job_id", "job_status", "step_index", "job_list", "job_create",
        "job_submit", "job_submit_all", "job_delete", "job_delete_all",
        "job_add_step", "job_remix_step", "job_insert_step",
        "job_remove_step", "job_run", "job_run_all", "job_retry",
        "job_retry_all", "source_pattern", "target_pattern",
        "output_pattern", "background-remover-model",
        "background-remover-color", "face_editor_model",
        "face_editor_eyebrow_direction", "face_editor_eye_gaze_horizontal",
        "face_editor_eye_gaze_vertical", "face_editor_eye_open_ratio",
        "face_editor_lip_open_ratio", "face_editor_mouth_grim",
        "face_editor_mouth_pout", "face_editor_mouth_purse",
        "face_editor_mouth_smile", "face_editor_head_pitch",
        "face_editor_head_yaw", "face_editor_head_roll",
    }

    about_keys = {"fund", "subscribe", "join"}

    uis_keys = {
        "apply_button", "benchmark_mode_dropdown",
        "benchmark_cycle_count_slider", "benchmark_resolutions_checkbox_group",
        "clear_button", "common_options_checkbox_group",
        "download_providers_checkbox_group",
        "execution_providers_checkbox_group", "execution_thread_count_slider",
        "face_detector_angles_checkbox_group", "face_detector_model_dropdown",
        "face_detector_margin_slider", "face_detector_score_slider",
        "face_detector_size_dropdown", "face_landmarker_model_dropdown",
        "face_landmarker_score_slider", "face_mask_blur_slider",
        "face_mask_padding_bottom_slider", "face_mask_padding_left_slider",
        "face_mask_padding_right_slider", "face_mask_padding_top_slider",
        "face_mask_areas_checkbox_group", "face_mask_regions_checkbox_group",
        "face_mask_types_checkbox_group", "face_selector_age_range_slider",
        "face_selector_gender_dropdown", "face_selector_mode_dropdown",
        "face_selector_order_dropdown", "face_selector_race_dropdown",
        "face_occluder_model_dropdown", "face_parser_model_dropdown",
        "voice_extractor_model_dropdown", "job_list_status_checkbox_group",
        "job_manager_job_action_dropdown", "job_manager_job_id_dropdown",
        "job_manager_step_index_dropdown", "job_runner_job_action_dropdown",
        "job_runner_job_id_dropdown", "log_level_dropdown",
        "output_audio_encoder_dropdown", "output_audio_quality_slider",
        "output_audio_volume_slider", "output_image_or_video",
        "output_image_quality_slider", "output_image_scale_slider",
        "output_path_textbox", "output_video_encoder_dropdown",
        "output_video_fps_slider", "output_video_preset_dropdown",
        "output_video_quality_slider", "output_video_scale_slider",
        "preview_frame_slider", "preview_image", "preview_mode_dropdown",
        "preview_resolution_dropdown", "processors_checkbox_group",
        "reference_face_distance_slider", "reference_face_gallery",
        "refresh_button", "source_file", "start_button", "stop_button",
        "system_memory_limit_slider", "target_file",
        "temp_frame_format_dropdown", "terminal_textbox", "trim_frame_slider",
        "ui_workflow", "video_memory_strategy_dropdown", "webcam_fps_slider",
        "webcam_image", "webcam_device_id_dropdown", "webcam_mode_radio",
        "webcam_resolution_dropdown",
    }

    result = {}
    result["help"] = {}
    result["about"] = {}
    result["uis"] = {}

    for key, value in flat_dict.items():
        if key in help_keys:
            result["help"][key] = value
        elif key in about_keys:
            result["about"][key] = value
        elif key in uis_keys:
            result["uis"][key] = value
        else:
            result[key] = value

    return result


import json

def patch_locales(locales_path: Path) -> bool:
    """在 locales.py 中添加 'zh' 中文翻译 — 使用 json.dumps 生成合法代码"""
    content = locales_path.read_text(encoding="utf-8")

    if "'zh'" in content or '"zh"' in content:
        print("  ✓ 中文语言已存在，跳过")
        return True

    zh_dict = build_nested_dict(ZH_TRANSLATIONS)

    # 使用 json.dumps 生成合法的 Python dict 字面量
    # json 与 Python 语法兼容，只需将 true/false 转为 True/False
    zh_block = json.dumps(zh_dict, indent=2, ensure_ascii=False)
    zh_block = zh_block.replace("true", "True").replace("false", "False").replace("null", "None")

    # 找到 LOCALES = { 后，'en': { ... } 的结束位置
    # 策略：找到文件末尾最后一个 '}' 的行，在它前面插入 'zh': ...,
    lines = content.splitlines()
    new_lines = []
    inserted = False

    for i, line in enumerate(lines):
        new_lines.append(line)
        if not inserted:
            stripped = line.strip()
            if stripped == "}" and not inserted:
                new_lines.insert(-1, "")
                new_lines.insert(-1, "\t" + '"zh": ' + zh_block.replace("\n", "\n\t").rstrip() + ",")
                new_lines.insert(-1, "")
                inserted = True

    if inserted:
        locales_path.write_text("\n".join(new_lines), encoding="utf-8")
        print(f"  ✓ 已添加中文翻译至 {locales_path}")
        return True

    print("  ✗ 未能定位插入点，请手动检查")
    return False


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("facefusion-master/facefusion")

    locales_main = src / "locales.py"

    if locales_main.exists():
        print("[1/1] 主 locales.py → 添加 'zh'")
        patch_locales(locales_main)
    else:
        print(f"✗ 找不到 {locales_main}")
        sys.exit(1)

    print("中文化补丁应用完成。")


if __name__ == "__main__":
    main()
