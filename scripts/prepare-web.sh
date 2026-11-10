#!/usr/bin/env bash
# Netlify 构建脚本：用当前 wasm 重新生成预压缩体。
#
# 只做一件事：保证 index.wasm.gz 与仓库里的 index.wasm 同步，
# 避免以后在 Godot 重新导出 Web 后忘记重新压缩、线上拿到旧引擎。
#
# 【重要 · 不要改 index.html 的 fileSizes.index.wasm】
# Godot 加载器（index.js / loadFetch -> getTrackedResponse）用
#   response.body.getReader() 累加 result.value.length 作为 loaded，
# 而浏览器会自动解压 Content-Encoding: gzip，所以 loaded 是「解压后字节数」
# = 原始 wasm 大小，不是传输的 gz 大小。
# fileSizes 必须保持 Godot 导出的未压缩字节数，进度条才准确。
# 2026-11-10 曾误把它改成 gz 大小（10084286），导致 loaded 迅速超过 total、
# 进度条一打开就爆满并停住；已撤销，勿再尝试。
#
# 只改 publish 目录里的构建产物，不会改仓库里的源文件。

set -euo pipefail

WEB="src/release/web"
WASM="$WEB/index.wasm"
GZ="$WEB/index.wasm.gz"

# -n 不写入原文件名/时间戳，保证同样输入产出完全相同的 gz（避免无意义 git diff）
gzip -k -9 -f -n "$WASM"
GZ_SIZE=$(stat -c %s "$GZ")

echo "prepare-web: index.wasm.gz = ${GZ_SIZE} bytes"
echo "prepare-web: index.html 的 fileSizes 保持 Godot 原值（勿改，见文件头注释）"
