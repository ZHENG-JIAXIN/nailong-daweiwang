#!/usr/bin/env bash
# Netlify 构建脚本：同步预压缩 wasm + 修正 Godot 加载进度条的字节数。
#
# 背景：
#  1) 线上 /index.wasm 由 netlify.toml / _redirects 重写到 index.wasm.gz，
#     浏览器实收的是 gzip 压缩体（约 9.6 MB），不是 38 MB 原始 wasm。
#  2) Godot 每次重新导出都会把 index.html 的 fileSizes.index.wasm 写成
#     未压缩字节数，进度条会卡在约 25% 再突然跳到 100%，看起来像卡死。
#  3) 仓库里的 index.wasm.gz 也可能与重新导出的 index.wasm 不同步。
#
# 本脚本用「当前 wasm」重新生成 gz，并把 fileSizes 改成 gz 的实际字节数。
# 数值自适应：以后关掉 Export With Debug 让 wasm 变小，脚本无需修改。
# 只改 publish 目录里的构建产物，不会改仓库里的源文件。

set -euo pipefail

WEB="src/release/web"
WASM="$WEB/index.wasm"
GZ="$WEB/index.wasm.gz"
HTML="$WEB/index.html"

# -n 不写入原文件名/时间戳，保证同样输入产出完全相同的 gz（避免无意义 git diff）
gzip -k -9 -f -n "$WASM"
GZ_SIZE=$(stat -c %s "$GZ")

# pck 未压缩，保持 Godot 原值；只替换 index.wasm 的字节数
sed -i -E "s/(\"index.wasm\"[[:space:]]*:[[:space:]]*)[0-9]+/\1${GZ_SIZE}/g" "$HTML"

echo "prepare-web: index.wasm.gz = ${GZ_SIZE} bytes"
echo -n "prepare-web: fileSizes -> "
grep -o 'fileSizes[^}]*}' "$HTML" | head -1 || true
