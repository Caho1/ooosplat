# FORK 说明（二开基座）

本仓库 fork 自 [ooolabdev/ooosplat](https://github.com/ooolabdev/ooosplat)（上游已保留为 `upstream` 远程）。

## 相对上游的改动

- 新增 `cloud/`：**无头云端流水线**，在无显示器的 Ubuntu 24.04 + NVIDIA GPU 主机上复用仓库锁定引擎（COLMAP 4.2.1 + OOOBrush ooo-v1.0.0）完成"多段多轨迹素材 → final.ply"，不依赖 Node.js/Tauri。详见 [cloud/README.md](cloud/README.md)。
- 其余代码与上游一致。

## 同步上游

```bash
git fetch upstream
git merge upstream/main        # 或 rebase，按团队习惯
```

## 桌面端开发（沿用上游流程）

```bash
npm ci
npm run setup:engines          # 按 manifest 恢复锁定引擎
npm run verify:engines
npm run tauri -- dev           # 或 ./scripts/start-app-linux.sh（Ubuntu）
```

- 引擎不提交到 Git，`engines/` 与 `.cache/engines/` 已被 gitignore。
- Ubuntu 24.04 依赖见根 README 的 "Ubuntu 24.04 Alpha" 一节。

## 许可与品牌义务（二开前必读）

- 代码为 Apache-2.0：分发修改版须保留 `LICENSE` / `NOTICE`。
- **"OOOSplat" 名称与 Logo 不在 Apache-2.0 授权范围内**。对外分发修改版需按 [TRADEMARK_POLICY.md](TRADEMARK_POLICY.md) 改名并去除官方标识。
- 第三方引擎（FFmpeg LGPL、COLMAP BSD-3-Clause、Brush Apache-2.0）各自许可不变，见 `licenses/THIRD_PARTY_NOTICES.txt`。
- 生成物（final.ply 等）的权属说明见 [GENERATED_OUTPUTS.md](GENERATED_OUTPUTS.md)。

## 二开方向建议

- **云端任务化**：把 `cloud/` 脚本包装成 HTTP 服务或队列消费者，即可做成"上传素材 → 回调 PLY"的重建服务（对应上游 ROADMAP 之外的能力）。
- **Planner 下沉**：`src-tauri/` 里的自动参数规划、桥接补帧、自动重试是纯 Rust 应用层逻辑，可抽出给无头模式复用。
- **全景支持**：`docs/PANORAMA_VIDEO_V1.md` / `PANORAMA_IMAGES_V1.md` 描述了 ERP 链路，可迁移到 cloud/。
