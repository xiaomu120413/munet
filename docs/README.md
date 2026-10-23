# 木络（MuNet）文档索引

这里是仓库文档的唯一入口。产品叫**木络**，英文名 **MuNet**，应用包名 `com.munet.app`；代码中的 `NetTools`、`libnettools.so` 等是历史命名，保留以兼容构建和已有本地数据。

## 先看这几份

| 文档 | 内容 |
|---|---|
| [README](../README.md) | 产品简介、功能状态、构建与部署 |
| [DESIGN](../DESIGN.md) | 架构、分层、接口契约、数据模型与合规边界 |
| [发布准备](RELEASE-READINESS.md) | 当前版本、候选产物与送审前待办 |
| [权限清单](PERMISSIONS.md) | 已声明权限与可扩展权限的申请边界 |
| [验证记录](verification/README.md) | UI、真机与自动化验证的阶段索引 |
| [发布与上架资料](release/README.md) | 签名、上架材料与历史发布快照 |

## 目录约定

| 目录 | 用途 | 说明 |
|---|---|---|
| `docs/design/` | 冻结的 UI 设计规范与图稿 | 视觉与布局的最终依据，后续补充决定见 `UI-DESIGN-UPDATES.md` |
| `docs/verification/` | 按阶段归档的验收证据 | 阶段编号越新越接近当前实现；旧阶段保留原始证据，不作为现状 |
| `docs/release/` | 按日期归档的发布快照 | `2026-10-23-submission` 是当前上架资料入口；旧目录仅用于追溯 |
| `docs/brand/` | 品牌源图、生成提示词与素材核对 | 图标源文件同时存在于 `AppScope/resources` |
| `artifacts/archive/`（本地） | 已移出仓库的历史归档 | 原始设计 ZIP 与 `docs/design` 内容重复，只保留在本机忽略目录，不入库 |

## 维护规则

1. 新增验证记录放到 `docs/verification/phaseN/`，并更新索引；不要直接堆在仓库根目录。
2. 新增发布资料放到 `docs/release/<日期>-<主题>/`，并在该目录 `README.md` 写清范围和结论。
3. 设计规范变更先改 `docs/UI-DESIGN-UPDATES.md`，再改实现；阶段报告只记录结果，不回写设计。
4. 截图和日志只保留能支撑结论的样本；构建日志中的本机绝对路径在入库前清理。
5. 证书、Profile、密钥、口令、设备签名包不进入 Git；签名材料放在仓库外或已忽略的 `sign_tools/`。
