# 木络权限与申请清单

核对日期：2026-10-23。包名 `com.mu.nettools`。依据本工程声明、DevEco Studio 当前 API 26 SDK 的权限资源及 API 注释；SDK 摘录见[权限证据](ui-verification/phase9/sdk-permissions.json)与[接口位置](ui-verification/phase9/sdk-network-api.json)。

## 当前版本需要的权限

| 权限 | 用途 | 等级／授权 | 当前处理 |
|---|---|---|---|
| `ohos.permission.INTERNET` | TCP 探测、端口扫描、域名解析、设备发现 | normal／system_grant | 已声明，当前能力无需另申请 ACL |
| `ohos.permission.GET_NETWORK_INFO` | 本机地址、网关、DNS、网络类型 | normal／system_grant | 已声明，当前能力无需另申请 ACL |
| `ohos.permission.GET_WIFI_INFO` | 读取已连接 Wi-Fi 的基础信息 | normal／system_grant | 已声明，当前能力无需另申请 ACL |

CSV／JSON 导出使用系统保存器选择路径，不需要申请全盘访问或读写全部用户文件。数据库保存在应用沙箱。当前不申请定位、通讯录、相机、麦克风或后台常驻权限；输入法自身的初始化页面与木络的权限无关。

## 扩展功能可以申请什么

以下能力尚未接入当前发布候选，申请成功后仍需开发、权限拒绝降级和真机验证。不要把申请权限视为功能已经完成，也不要将 SDK 的 `provisionEnable=true` 视为 AGC 一定批准。

| 优先级 | 权限 | 可支持的扩展 | SDK 条件与申请说明 |
|---|---|---|---|
| 优先 | `ohos.permission.GET_IP_MAC_INFO` | 邻居表的 IP／MAC 映射；系统 TCP／UDP 端口信息 | system_basic／system_grant，ACL 可配置。`getIpNeighTable` since 22，还需 GET_NETWORK_INFO；`getSystemNetPortStates` since 24。邻居表只是缓存，不能声称覆盖全部局域网设备。需在 AGC 核对当前账号和应用场景的可申请性 |
| 需要流量页时 | `ohos.permission.GET_NETWORK_STATS` | 网络流量统计 | system_basic／system_grant，ACL 可配置；此前真机实测未授权。批准后再按具体统计接口和系统版本核验范围，不能据此承诺抓包或流量内容分析 |
| 确实要显示本机 MAC 时 | `ohos.permission.GET_WIFI_LOCAL_MAC` | 本机 WLAN MAC | system_basic／system_grant，ACL 可配置；不能替代邻居设备 MAC 权限。当前没有该字段，不是本版必需 |
| 另做路由追踪时 | `ohos.permission.ACCESS_NET_TRACE_INFO` | API 26 的 `queryTraceRoute` | system_basic／system_grant，ACL 可配置；该接口同时要求 INTERNET、LOCATION、APPROXIMATELY_LOCATION。后两项为用户授权。当前没有路由追踪页，不随本版申请定位 |

API 26 另有 `queryProbeResult`，注释只要求 INTERNET，可取得丢包和 RTT；尚未验证运行语义、取消行为或旧系统降级，不将其当作本轮已经实现的 ICMP Ping。当前 Ping 仍为 TCP 探测。没有必要为当前版本申请 root 或尝试突破应用沙箱。

## 给申请表准备的用途草稿

**GET_IP_MAC_INFO（拟新增功能）**：用户主动进行本地网络设备识别和端口诊断时，读取系统邻居缓存中的 IP 与 MAC 映射，以及本机系统端口状态，帮助定位连接与端口占用问题。数据仅在本机展示处理，不用于定位、广告或用户画像，不上传服务器。未授权时保留现有 TCP 扫描，隐藏新增字段并说明不可用。

**GET_NETWORK_STATS（仅在确定做流量页后申请）**：用户主动查看本机网络流量统计，展示系统允许范围内的收发字节与变化情况；不读取数据包内容，不上传统计。未授权时不显示流量页，既有网络诊断不受影响。

草稿需与实际开发的页面和演示材料一致；当前不能提供这些未实现页面的完成截图。APP ID、开发者账号、签名证书等以 AGC 实际信息填写，不使用本地调试 App ID 代替。

## 批准后的接入

在 AGC 为对应应用申请；获批后将权限加入正确的调试／发布 Profile，同时在模块声明所需权限，再构建签名验证。仅改 `requestPermissions` 或给普通运行时授权，不能代替 ACL 授权。保持现有包名与证书关联，不提交私钥或 Profile 到 Git。

官方入口：[受限权限申请](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/declare-permissions-in-acl)、[受限开放权限列表](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/restricted-permissions)、[调试 Profile 配置](https://developer.huawei.com/consumer/cn/doc/doccenter-getting-started/agc-help-debug-profile-0000002248181278)。本次官网部分正文抓取超时，因此具体权限和接口结论以上述本机 SDK 证据为准；申请资格和审核结果以 AGC 当前页面为准。
