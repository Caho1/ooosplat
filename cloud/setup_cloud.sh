#!/usr/bin/env bash
# cloud/setup_cloud.sh — 云主机（Ubuntu 24.04 x86_64 + NVIDIA GPU）环境安装
#
# 与桌面端 `npm run setup:engines` 等价，但不依赖 Node.js：
# 直接按 engines/manifest.linux.json 里锁定的 URL 和 SHA-256 安装引擎，
# 布局与桌面端一致：
#   engines/linux/colmap/bin/colmap      COLMAP 4.2.1（CUDA + Caspar/Ceres）
#   engines/linux/brush/brush_app        OOOBrush ooo-v1.0.0 无界面训练器
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/engines/manifest.linux.json"
CACHE="$REPO_ROOT/.cache/engines"
mkdir -p "$CACHE"

echo "==> [1/4] 系统依赖"
sudo apt update
sudo apt install -y ffmpeg curl jq xz-utils libvulkan1 vulkan-tools

echo "==> [2/4] GPU 检查"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
  DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
  echo "    要求驱动 ≥ 580.00、Compute Capability ≥ 7.5（当前驱动 $DRV）"
else
  echo "⚠️  未检测到 NVIDIA 驱动：COLMAP 回退 CPU，Brush 训练可能无法启动。"
fi

fetch_pinned() {
  # $1 jq 路径前缀（colmap / brush） $2 目标解压目录
  local key="$1" dest="$2"
  local url name sha
  url="$(jq -r ".$key.sourceUrl" "$MANIFEST")"
  name="$(jq -r ".$key.archiveName" "$MANIFEST")"
  sha="$(jq -r ".$key.archiveSha256" "$MANIFEST" | tr 'A-F' 'a-f')"
  [ "$url" != "null" ] || { echo "❌ manifest 中缺少 $key.sourceUrl"; exit 1; }

  if [ ! -f "$CACHE/$name" ]; then
    echo "    下载 $name"
    curl -fSL --retry 3 -o "$CACHE/$name" "$url"
  else
    echo "    使用缓存 $name"
  fi
  echo "    校验 SHA-256（manifest 锁定值）"
  echo "$sha  $CACHE/$name" | sha256sum -c - || { echo "❌ 哈希不匹配"; exit 1; }

  mkdir -p "$dest"
  case "$name" in
    *.tar.xz) tar -xJf "$CACHE/$name" -C "$dest" ;;
    *.tar.gz) tar -xzf "$CACHE/$name" -C "$dest" ;;
    *.zip)    unzip -qo "$CACHE/$name" -d "$dest" ;;
  esac
}

echo "==> [3/4] COLMAP 4.2.1 → engines/linux/colmap"
COLMAP_DEST="$REPO_ROOT/engines/linux/colmap"
if [ ! -x "$COLMAP_DEST/bin/colmap" ]; then
  tmp="$(mktemp -d)"
  fetch_pinned colmap "$tmp"
  # 包内可能多套一层目录，归位到 dest 根
  if [ -x "$tmp/bin/colmap" ]; then
    rm -rf "$COLMAP_DEST"; mkdir -p "$COLMAP_DEST"; mv "$tmp"/* "$COLMAP_DEST"/
  else
    inner="$(dirname "$(find "$tmp" -type f -name colmap -path '*/bin/*' | head -n1)")/.."
    rm -rf "$COLMAP_DEST"; mkdir -p "$COLMAP_DEST"; mv "$inner"/* "$COLMAP_DEST"/
  fi
  rm -rf "$tmp"
else
  echo "    已存在，跳过"
fi
[ -f "$COLMAP_DEST/lib/colmap/vocab_tree_faiss_flickr100K_words256K.bin" ] \
  && echo "    离线词袋 ✅" || echo "    ⚠️  缺离线词袋，大图集只能用穷举匹配"

echo "==> [4/4] OOOBrush ooo-v1.0.0 → engines/linux/brush/brush_app"
BRUSH_DEST="$REPO_ROOT/engines/linux/brush"
if [ ! -x "$BRUSH_DEST/brush_app" ]; then
  tmp="$(mktemp -d)"
  fetch_pinned brush "$tmp"
  cli="$(find "$tmp" -type f -name brush-cli | head -n1)"
  [ -n "$cli" ] || { echo "❌ 包内未找到 brush-cli"; exit 1; }
  mkdir -p "$BRUSH_DEST"
  # 桌面端约定：headless brush-cli 重命名为 brush_app
  cp "$cli" "$BRUSH_DEST/brush_app" && chmod +x "$BRUSH_DEST/brush_app"
  # 校验可执行文件哈希（manifest 锁定值）
  bin_sha="$(jq -r '.brush.binarySha256' "$MANIFEST" | tr 'A-F' 'a-f')"
  echo "$bin_sha  $BRUSH_DEST/brush_app" | sha256sum -c - \
    && echo "    brush_app 哈希校验 ✅" || { echo "❌ brush_app 哈希不匹配"; exit 1; }
  rm -rf "$tmp"
else
  echo "    已存在，跳过"
fi

echo
echo "✅ 云端环境就绪（引擎布局与桌面端一致，可用 npm run verify:engines 复核）"
echo "   用法：bash cloud/run_cloud.sh <项目目录> <fast|balanced|fine> <素材1> [素材2 ...]"
