#!/usr/bin/env bash
# cloud/brush_train.sh — Brush 无界面训练 + 导出 final.ply
# 用法：brush_train.sh <项目目录> <训练步数> <训练分辨率上限> [点数上限]
# 参数名以 OOOBrush ooo-v1.0.0 源码（clap 定义）为准；全集见 brush_app --help。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRUSH="$REPO_ROOT/engines/linux/brush/brush_app"
[ -x "$BRUSH" ] || { echo "❌ 未找到 brush_app，请先跑 cloud/setup_cloud.sh"; exit 1; }

PROJECT_DIR="$(cd "$1" && pwd)"
ITERS="$2"; MAX_RES="$3"; MAX_SPLATS="${4:-10000000}"
WORK="$PROJECT_DIR/work"
DATASET="$WORK/brush_dataset"
EXPORTS="$PROJECT_DIR/exports"
LOGS="$PROJECT_DIR/logs"
mkdir -p "$DATASET" "$EXPORTS" "$LOGS"

# Brush 识别标准 COLMAP 数据集布局：<dir>/images + <dir>/sparse/0/*.bin
[ -d "$WORK/colmap/sparse/0" ] || { echo "❌ 未找到 COLMAP 模型，请先跑 colmap_reconstruct.sh"; exit 1; }
ln -sfn "$WORK/images" "$DATASET/images"
ln -sfn "$WORK/colmap/sparse" "$DATASET/sparse"

echo "==> 训练：$ITERS 步，分辨率上限 $MAX_RES，点数上限 $MAX_SPLATS"
echo "    （OOM 时降低点数上限或分辨率上限重试本步即可，前面成果保留）"

# OOOBrush 官方建议的诊断日志
export RUST_LOG=info
export RUST_BACKTRACE=1

"$BRUSH" "$DATASET" \
  --total-train-iters "$ITERS" \
  --max-resolution "$MAX_RES" \
  --max-splats "$MAX_SPLATS" \
  --eval-split-every 8 \
  --export-every 5000 \
  --export-path "$EXPORTS" \
  --export-name "export_{iter}.ply" \
  2>&1 | tee "$LOGS/brush_train.log"

FINAL_SRC="$(ls -1t "$EXPORTS"/export_*.ply 2>/dev/null | head -n1 || true)"
if [ -z "$FINAL_SRC" ]; then
  echo "❌ 训练结束但未找到导出 PLY。检查 $LOGS/brush_train.log"
  echo "   （OOOBrush 约定：进程退出码不代表导出成功，导出失败仅告警。）"
  exit 1
fi
cp -f "$FINAL_SRC" "$PROJECT_DIR/final.ply"

echo
echo "✅ 训练完成：$PROJECT_DIR/final.ply（$(du -h "$PROJECT_DIR/final.ply" | cut -f1)，来自 $(basename "$FINAL_SRC")）"
echo "   中间检查点保留在 $EXPORTS/"
