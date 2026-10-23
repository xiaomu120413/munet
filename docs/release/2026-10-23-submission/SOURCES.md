# 资料依据与核对边界

核对日期2026-10-23。以下只依赖官方来源和本项目证据，不用旧Android/APK材料推断鸿蒙原生APP要求。

| 官方来源 | 本轮确认的内容 | 使用边界 |
|---|---|---|
| [应用市场分发入口](https://developer.huawei.com/consumer/cn/appgallery/devstart/) | 开发者实名、团队访问、应用资料、隐私声明／托管和APP备案入口 | 未登录账号，不代表该包名已注册、资质已通过或实际上传表单已核验 |
| [提交HarmonyOS应用](https://developer.huawei.com/consumer/cn/app/submit/) | APP发布流程、上架前安全／隐私及质量检查、图标与截图等展示资料 | 不据入口摘要编造各类目的强制资质或图片尺寸 |
| [云测试上架测试](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/agc-help-cloudtest-releasetest-0000002289646673) | Release签名包；隐私测试依赖对应账号／团队及隐私声明、标签配置；测试覆盖多个质量专项 | 页面更新日期2026-10-13；通过测试不等于审核通过，也不将每个具体云测试服务说成所有应用统一强制 |
| [发布签名／云测试FAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-testing/agc-help-cloudtest-faq-0000002255036920) | 提供官方核对入口 | 本轮直接打开未获得可用正文，正式签名实际配置以后台和官方流程核对 |
| [ACL配置说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/declare-permissions-in-acl)／[受限权限列表](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions) | 提供受限权限办理入口 | 本轮未获得可用权限正文，不能据此保证GET_IP_MAC_INFO的账号资格或批准结果 |

## 本地证据

- AppScope/app.json5：com.munet.app、MuGe、0.4.0／1000004。
- entry/src/main/module.json5：手机／平板／2in1，只有三项普通网络权限。
- build-profile.json5：最低API22、目标API26，正式签名配置为空；不能把本地调试Profile当正式发布材料。
- [SDK权限定义](../../ui-verification/phase9/sdk-permissions.json)和[接口位置](../../ui-verification/phase9/sdk-network-api.json)：等级、授权方式及版本依据；这些是API定义证据，不把旧包权限实测套用于新包授权。
- [最新验收](../2026-10-23-munet-app/README.md)：默认18项测试及平台UI综合用例的真实运行结果，来源为PC实机及手机／平板模拟器。
- scripts/check_release.py及[发布产物复核](submission-inventory.json)：unsigned APP／HAP、运行源码和测试证据哈希。

没有取得运营主体、后台APP ID、正式证书／Profile、政策URL或备案结果，不制作虚构值。正式包上架前仍需补最终质量与素材；该资料包的状态始终是准备完成、等待开发者资料，不是已经上传或审核通过。
