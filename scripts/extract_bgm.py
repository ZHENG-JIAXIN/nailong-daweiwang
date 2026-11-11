#!/usr/bin/env python3
"""从本地音视频文件提取音轨，压成 Godot Web 可用的 BGM。

用法：
    python scripts/extract_bgm.py "D:/path/to/video.mp4"

输出：src/assets/audio/bgm.ogg（ffmpeg 无 libvorbis 时退回 bgm.mp3）
参数：96 kb/s / 48 kHz / stereo —— 约 2~3 MB，避免拖慢移动端首包。

依赖：python -m pip install imageio-ffmpeg（自带 ffmpeg 二进制，无需系统安装）
输出后必须在 Godot 里重新导出 Web，再 git push，线上才会更新。
"""

import os
import subprocess
import sys

try:
    import imageio_ffmpeg
except ImportError:
    sys.exit("缺少 imageio-ffmpeg，请先运行：python -m pip install imageio-ffmpeg")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO_DIR = os.path.join(ROOT, "src", "assets", "audio")


def main():
    if len(sys.argv) < 2:
        sys.exit("用法：python scripts/extract_bgm.py <音视频文件>")
    src = sys.argv[1]
    if not os.path.isfile(src):
        sys.exit("找不到输入文件：" + src)

    ff = imageio_ffmpeg.get_ffmpeg_exe()
    encoders = subprocess.run(
        [ff, "-hide_banner", "-encoders"],
        capture_output=True, text=True, errors="replace",
    ).stdout

    if "libvorbis" in encoders:
        out = os.path.join(AUDIO_DIR, "bgm.ogg")
        codec = ["-c:a", "libvorbis", "-b:a", "96k"]
    elif "libmp3lame" in encoders:
        out = os.path.join(AUDIO_DIR, "bgm.mp3")
        codec = ["-c:a", "libmp3lame", "-b:a", "96k"]
    else:
        sys.exit("ffmpeg 缺少 libvorbis / libmp3lame，无法输出 Godot 可用格式")

    cmd = [
        ff, "-hide_banner", "-loglevel", "error",
        "-i", src, "-vn",
        *codec,
        "-ar", "48000", "-ac", "2",
        "-y", out,
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    if r.returncode != 0:
        sys.exit("转码失败：\n" + r.stderr[-2000:])

    size = os.path.getsize(out)
    print("已生成：%s（%.2f MB）" % (out, size / 1048576.0))
    print("下一步：Godot 重新导出 Web → git add . && commit && push")


if __name__ == "__main__":
    main()
