#!/usr/bin/env bash
# cloud/run_cloud.sh — 云端一键生成（对应桌面端"一键生成"）
# 用法：run_cloud.sh <项目目录> <fast|balanced|fine> <素材1> [素材2 ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$#" -ge 3 ] || {
  echo "用法：bash cloud/run_cloud.sh <项目目录> <fast|balanced|fine> <素材1> [素材2 ...]"
  exit 1
}
PROJECT_DIR="$1"; TIER="$2"; shift 2
mkdir -p "$PROJECT_DIR"

# 档位映射对齐 OOOSplat 0.8.0：
#   fast     = 快速：  6 FPS，COLMAP 1200/4096，  8,000 步，训练分辨率 ≤1280
#   balanced = 均衡：  8 FPS，COLMAP 1600/8192， 15,000 步，训练分辨率 ≤1920
#   fine     = 精细： 12 FPS，COLMAP 3200/16384，30,000 步，训练分辨率 ≤3200
case "$TIER" in
  fast)     FPS=6;  COLMAP_SIZE=1200; COLMAP_FEAT=4096;  ITERS=8000;  MAX_RES=1280 ;;
  balanced) FPS=8;  COLMAP_SIZE=1600; COLMAP_FEAT=8192;  ITERS=15000; MAX_RES=1920 ;;
  fine)     FPS=12; COLMAP_SIZE=3200; COLMAP_FEAT=16384; ITERS=30000; MAX_RES=3200 ;;
  *) echo "❌ 档位必须是 fast / balanced / fine"; exit 1 ;;
esac

echo "┌──────────────────────────────────────────────┐"
echo "│  OOOSplat 云端流水线 · 档位 $TIER"
echo "│  项目：$PROJECT_DIR"
echo "└──────────────────────────────────────────────┘"

bash "$SCRIPT_DIR/extract_frames.sh"      "$PROJECT_DIR" "$FPS" "$@"
bash "$SCRIPT_DIR/colmap_reconstruct.sh"  "$PROJECT_DIR" "$COLMAP_SIZE" "$COLMAP_FEAT"
bash "$SCRIPT_DIR/brush_train.sh"         "$PROJECT_DIR" "$ITERS" "$MAX_RES"

echo
echo "🎉 全流程完成：$PROJECT_DIR/final.ply"
