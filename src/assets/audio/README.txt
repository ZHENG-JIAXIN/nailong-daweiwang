奶龙大胃王 —— BGM 音源目录
============================

把你的背景音乐文件放进这个文件夹，命名为以下任一格式即可自动生效：

    bgm.ogg
    bgm.mp3
    bgm.wav

（程序在 audio_player.gd 里用 preload 固定加载一个文件，找不到时才回退到内置合成音乐。
 当前固定为 bgm.ogg。换歌时要么覆盖同名文件，要么改 audio_player.gd 里的 preload 路径。）

推荐流程：python scripts/extract_bgm.py "你的音视频文件"
（依赖：python -m pip install imageio-ffmpeg，自带 ffmpeg 二进制，无需系统安装）
脚本会提取音轨并压成 96 kb/s / 48 kHz / stereo 的 Ogg，约 2~3 MB，不拖慢手机首包。

重要提醒：
- 请只使用你拥有权利的音乐：自己的原创、免版税（royalty-free）曲库下载的、或已获作者授权的曲子。
  常见免版税来源：YouTube 音频库、Pixabay Music、Free Music Archive、ccMixter。
- 放入新文件后，必须「重新导出 Web」（Godot 编辑器 → 项目 → 导出 → Web → 导出项目），
  再 git push，线上才会更新。仅改本地文件不会自动生效。
- 文件名必须与 audio_player.gd 的 preload 路径一致（当前是 bgm.ogg，小写）。

当前使用的 BGM（署名 / 版权说明）
--------------------------------
音源：src/assets/audio/bgm.ogg —— 由用户提供的音视频文件提取音轨，
      转码为 Ogg Vorbis / 96 kb/s / 48 kHz / stereo / 3分37秒 / 2.30 MB。
授权：用户已确认其拥有该曲目的相应权利；公开发布前请在此处补齐
      具体授权来源、作者署名与许可范围（由用户自行维护）。
备份：bgm.wav（耳聆网「轻度节奏打击乐」，声音 ID 20713）保留作回退，
      程序当前不再引用；如需精简 pck 可删除该 wav 与其 .import。

浏览器自动播放策略（重要）
--------------------------
Web 浏览器不允许「没有任何用户交互就播放有声音频」，这与音乐文件本身无关。
因此 audio_player.gd 采用：页面加载后先静音起播（让解码与 AudioContext 就绪），
玩家第一次点击 / 按键 / 触摸时立即解除静音，不重启播放、无空白、不从头开始。
登录页也加了对应提示。不要改成「手势后 stop()+play()」，那会重新出现空白与从头播放。
另：请只放纯音频文件（ogg/mp3/wav），MP4/MV 视频容器 Godot Web 不能直接当 BGM 用，
且大文件会显著拖慢手机首次加载。
