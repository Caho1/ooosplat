#!/usr/bin/env bash
# cloud/colmap_reconstruct.sh — 多轨迹联合重建（COLMAP 4.2.1）
# 用法：colmap_reconstruct.sh <项目目录> <colmap长边> <最大特征数>
#
# 匹配策略（对应桌面端"多素材联合重建"）：
#   ≤1500 帧 → exhaustive_matcher（穷举，跨轨迹全覆盖，最稳）
#   >1500 帧 → vocab_tree_matcher（引擎包内置离线词袋）
# 多段不同轨迹不要用 sequential_matcher：它只按文件名顺序匹配相邻帧，
# 跨轨迹的视角重叠会被漏掉。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLMAP="$REPO_ROOT/engines/linux/colmap/bin/colmap"
VOCAB="$REPO_ROOT/engines/linux/colmap/lib/colmap/vocab_tree_faiss_flickr100K_words256K.bin"
[ -x "$COLMAP" ] || { echo "❌ 未找到 COLMAP，请先跑 cloud/setup_cloud.sh"; exit 1; }

PROJECT_DIR="$(cd "$1" && pwd)"; IMG_SIZE="$2"; MAX_FEAT="$3"
IMAGES="$PROJECT_DIR/work/images"
CM_DIR="$PROJECT_DIR/work/colmap"
DB="$CM_DIR/database.db"
SPARSE="$CM_DIR/sparse"
LOGS="$PROJECT_DIR/logs"
mkdir -p "$CM_DIR" "$SPARSE" "$LOGS"
[ -d "$IMAGES" ] || { echo "❌ 未找到 $IMAGES，请先跑 extract_frames.sh"; exit 1; }

N_IMAGES=$(find "$IMAGES" -maxdepth 1 -name '*.jpg' | wc -l)
echo "==> 输入 $N_IMAGES 帧，COLMAP 长边 $IMG_SIZE，特征上限 $MAX_FEAT"

if command -v nvidia-smi >/dev/null 2>&1; then GPU=1; else GPU=0; echo "    （无 NVIDIA GPU，SIFT 使用 CPU，较慢）"; fi

echo "==> [1/3] 特征提取"
"$COLMAP" feature_extractor \
  --database_path "$DB" \
  --image_path "$IMAGES" \
  --ImageReader.single_camera 1 \
  --ImageReader.max_image_size "$IMG_SIZE" \
  --SiftExtraction.max_num_features "$MAX_FEAT" \
  --SiftExtraction.use_gpu "$GPU" \
  2>&1 | tee "$LOGS/colmap_feature_extractor.log"

echo "==> [2/3] 特征匹配"
if [ "$N_IMAGES" -le 1500 ]; then
  echo "    $N_IMAGES ≤ 1500，穷举匹配"
  "$COLMAP" exhaustive_matcher --database_path "$DB" \
    --SiftMatching.use_gpu "$GPU" 2>&1 | tee "$LOGS/colmap_matcher.log"
elif [ -f "$VOCAB" ]; then
  echo "    $N_IMAGES > 1500，词袋匹配"
  "$COLMAP" vocab_tree_matcher --database_path "$DB" \
    --VocabTreeMatching.vocab_tree_path "$VOCAB" \
    --VocabTreeMatching.num_images 100 \
    --SiftMatching.use_gpu "$GPU" 2>&1 | tee "$LOGS/colmap_matcher.log"
else
  echo "    ⚠️  缺词袋文件，回退穷举匹配"
  "$COLMAP" exhaustive_matcher --database_path "$DB" \
    --SiftMatching.use_gpu "$GPU" 2>&1 | tee "$LOGS/colmap_matcher.log"
fi

echo "==> [3/3] 增量重建（SfM）"
"$COLMAP" mapper \
  --database_path "$DB" \
  --image_path "$IMAGES" \
  --output_path "$SPARSE" \
  2>&1 | tee "$LOGS/colmap_mapper.log"

MODEL="$SPARSE/0"
[ -f "$MODEL/images.bin" ] || { echo "❌ 重建失败，检查 $LOGS/colmap_mapper.log"; exit 1; }

echo
echo "==> 重建统计"
"$COLMAP" model_analyzer --path "$MODEL" 2>&1 | tee "$LOGS/colmap_model_analyzer.log"

REGISTERED=$(python3 -c "
import struct
with open('$MODEL/images.bin','rb') as f:
    print(struct.unpack('<Q', f.read(8))[0])")
RATE=$(python3 -c "print(f'{$REGISTERED/$N_IMAGES*100:.1f}')")
echo
echo "✅ 注册画面 $REGISTERED / $N_IMAGES（注册率 ${RATE}%），模型在 $MODEL"
python3 -c "exit(0 if $REGISTERED/$N_IMAGES >= 0.8 else 1)" \
  || echo "⚠️  注册率低于 80%：轨迹间视角重叠可能不足。训练仍可继续，建议补充重叠素材后重建。"
