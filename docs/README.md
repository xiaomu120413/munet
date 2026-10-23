# 木络（MuNet）文档索引

这里是仓库文档的唯一入口。产品叫**木络**，英文名 **MuNet**，应用包名 `com.munet.app`；代码中的 `NetTools`、`libnettools.so` 等是历史命名，保留以兼容构建和已有本地数据。

## 文档

| 文档 | 内容 |
|---|---|
| [README](../README.md) | 产品简介、功能状态、构建与部署 |
| [DESIGN](DESIGN.md) | 架构、分层、接口契约、数据模型与合规边界 |
| [RELEASE-READINESS](RELEASE-READINESS.md) | 当前版本、发布包与送审前待办 |
| [PERMISSIONS](PERMISSIONS.md) | 已声明权限与可扩展权限的申请边界 |
| [UI-MIGRATION](UI-MIGRATION.md) | UI 改造过程与阶段结论 |
| [UI-DESIGN-UPDATES](UI-DESIGN-UPDATES.md) | 对冻结设计稿的补充决定 |
| [design/](design/README.md) | 冻结 UI 规范、图稿与生成提示词 |

## 目录约定

| 目录 | 用途 |
|---|---|
| `docs/design/` | 冻结的 UI 设计规范与图稿，视觉与布局的最终依据 |
| `artifacts/`（本地忽略） | 签名、构建与发布产物，不进入 Git |
| `sign_tools/`（本地忽略） | 证书、Profile、密钥与签名配置，不进入 Git |

历史阶段的验证截图、发布快照和品牌过程文件已由维护者清理，不再随仓库分发；需要时从本机 `artifacts/` 或版本发布记录中查找。

## 维护规则

1. 长期文档只保留仍对当前版本有指导意义的内容；一次性验证截图和构建日志不提交。
2. 设计规范变更先改 `docs/UI-DESIGN-UPDATES.md`，再改实现。
3. 新增文档直接放到 `docs/`，并在本页登记；不要再建按日期堆叠的目录。
4. 证书、Profile、密钥、口令、签名安装包不进入 Git。
5. 提交前检查 Markdown 相对链接和本机绝对路径。
