# cloud/ — 无头云端流水线

在**无显示器的云 GPU 主机**上运行 OOOSplat 的核心生成链路（多段多轨迹素材 → `final.ply`），不依赖桌面 GUI、Node.js 或 Tauri。
引擎复用仓库自带的锁定版本（`engines/manifest.linux.json`），与桌面端 0.8.0 完全一致。

## 环境

- Ubuntu 24.04 LTS x86_64
- NVIDIA GPU：驱动 ≥ 580.00，Compute Capability ≥ 7.5；建议显存 ≥ 16 GB（fine 档）
- 磁盘：预留素材体积 5 倍以上

## 用法

```bash
# 1. 安装系统依赖并按 manifest 锁定值下载/校验引擎
bash cloud/setup_cloud.sh

# 2. 一键生成（多段素材全部传入，自动联合重建）
bash cloud/run_cloud.sh ~/projects/my-scene fine \
  /data/clip_orbit_1.mp4 \
  /data/clip_orbit_2.mp4 \
  /data/photos_extra/        # 图片文件夹也可以混合传入
```

产物：`<项目目录>/final.ply`，中间成果在 `work/`、检查点在 `exports/`、日志在 `logs/`。

## 档位（对齐桌面端 0.8.0）

| 档位 | 抽帧 FPS | COLMAP 长边/特征数 | 训练步数 | 训练分辨率 |
|---|---|---|---|---|
| `fast` | 6 | 1200 / 4096 | 8,000 | ≤1280 |
| `balanced` | 8 | 1600 / 8192 | 15,000 | ≤1920 |
| `fine` | 12 | 3200 / 16384 | 30,000 | ≤3200 |

## 分步执行 / 断点续跑

```bash
bash cloud/extract_frames.sh     <项目目录> <FPS> <素材...>
bash cloud/colmap_reconstruct.sh <项目目录> <长边> <特征数>
bash cloud/brush_train.sh        <项目目录> <步数> <分辨率> [点数上限]
```

GPU OOM：给 `brush_train.sh` 传第四个参数压点数（如 `5000000`），或降分辨率上限，重跑本步即可。

## 多轨迹素材要点

- 轨迹之间必须有视角重叠；重建后看日志中的注册率，≥80% 才稳。
- 匹配策略：≤1500 帧穷举匹配、>1500 帧词袋匹配（词袋随 COLMAP 引擎包内置），保证跨轨迹匹配不遗漏。
- 同一台相机拍摄时脚本默认共享内参（`--ImageReader.single_camera 1`）；多设备混拍时删掉该参数。

## 与桌面端的关系

| 能力 | 桌面端 OOOSplat | cloud/ 流水线 |
|---|---|---|
| 多素材联合重建、三档策略 | ✅ | ✅（参数对齐） |
| 普通视频/图片序列 | ✅ | ✅ |
| 全景 ERP 素材 | ✅ | ❌（应用层逻辑，未迁移） |
| 补拍 / 断点续跑（任务级） | ✅ | 部分（脚本级断点重跑） |
| 预览 / 编辑 / 多格式导出 | ✅ | ❌（把 `final.ply` 拉回本地用桌面端导入） |
| 桥接补帧、自动重试、GPS 辅助 | ✅ | ❌（Planner 应用层逻辑） |

需要完整能力（补拍、Planner 自动参数、全景）时，可在本仓库继续二开——这些是 `src-tauri/`（Rust）与 `src/`（React）里的应用层逻辑。
