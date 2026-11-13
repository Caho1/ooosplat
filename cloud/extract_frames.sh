#!/usr/bin/env bash
# cloud/extract_frames.sh — 多段素材抽帧/收拢到统一的 images/ 目录
# 用法：extract_frames.sh <项目目录> <fps> <素材1> [素材2 ...]
#   素材可以是视频文件（mp4/mov…）或图片文件夹；每段以独立前缀命名。
set -euo pipefail

PROJECT_DIR="$(cd "$1" && pwd)"; FPS="$2"; shift 2
[ "$#" -ge 1 ] || { echo "❌ 至少需要一个素材"; exit 1; }

WORK="$PROJECT_DIR/work"
FRAMES_RAW="$WORK/frames_raw"
IMAGES="$WORK/images"
LOGS="$PROJECT_DIR/logs"
mkdir -p "$FRAMES_RAW" "$IMAGES" "$LOGS"

total=0
for src in "$@"; do
  [ -e "$src" ] || { echo "❌ 素材不存在：$src"; exit 1; }
  base="$(basename "$src")"; seg="${base%.*}"
  seg="$(echo "$seg" | tr -cs 'A-Za-z0-9_-' '_' | sed 's/^_//;s/_$//')"
  out="$FRAMES_RAW/$seg"
  mkdir -p "$out"

  if [ -d "$src" ]; then
    echo "==> 图片集 $base → 收拢"
    n=0
    find "$src" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort | while read -r img; do
      n=$((n+1))
      printf -v idx '%05d' "$n"
      ln -f "$img" "$out/${seg}_${idx}.jpg" 2>/dev/null || cp "$img" "$out/${seg}_${idx}.jpg"
    done
  else
    echo "==> 视频 $base → 抽帧 ${FPS} FPS"
    ffmpeg -hide_banner -loglevel error -i "$src" \
      -vf "fps=${FPS}" -q:v 2 -start_number 1 \
      "$out/${seg}_%05d.jpg" 2>&1 | tee "$LOGS/ffmpeg_${seg}.log"
  fi

  for f in "$out"/*.jpg; do
    [ -e "$f" ] || continue
    ln -f "$f" "$IMAGES/$(basename "$f")" 2>/dev/null || cp "$f" "$IMAGES/$(basename "$f")"
  done
  cnt=$(ls "$IMAGES" | grep -c "^${seg}_" || true)
  echo "    $seg：$cnt 帧"
  total=$((total+cnt))
done

echo
echo "✅ 抽帧完成，共 $total 帧 → $IMAGES"
[ "$total" -lt 30 ] && echo "⚠️  帧数少于 30，重建大概率失败，请提高 FPS 或补充素材。" || true
