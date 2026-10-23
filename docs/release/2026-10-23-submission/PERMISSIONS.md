# com.muge.munet权限与申请范围

当前首发版不需要额外申请ACL。这里把应用运行权限与开发者后台角色、签名证书及备案材料分开列明，避免将不同事项混为一谈。

## 当前已声明

| 完整权限名 | 用途 | SDK等级／授权方式 | 你是否需要另行申请 |
|---|---|---|---|
| ohos.permission.INTERNET | TCP连接、端口扫描、DNS／mDNS通信 | normal／system_grant | 不需要ACL，已声明 |
| ohos.permission.GET_NETWORK_INFO | 本机网络类型、地址、网关、DNS等 | normal／system_grant | 不需要ACL，已声明 |
| ohos.permission.GET_WIFI_INFO | 系统允许读取的当前Wi-Fi基础信息 | normal／system_grant | 不需要ACL，已声明 |

上表来自当前module.json5和冻结SDK权限定义。系统授权不是商店隐私声明：即使没有运行时弹窗，也必须如实说明数据行为。导出使用系统保存器，无需全盘存储权限；当前无定位、相机、通讯录、麦克风、后台常驻需求。

## 后续功能才考虑

| 权限 | 拟新增用途与边界 | 是否阻塞首版 |
|---|---|---|
| ohos.permission.GET_IP_MAC_INFO | 邻居缓存IP／MAC映射及系统端口状态。system_basic／system_grant；SDK provisionEnable=true表示可配置性，不保证账号有申请资格或获批。getIpNeighTable since22，另需GET_NETWORK_INFO；getSystemNetPortStates since24。缓存不能保证完整发现全部局域网设备 | 否；如要扩展，优先核对资格 |
| ohos.permission.GET_NETWORK_STATS | 未来流量统计；不等于抓包或读取网络内容 | 否；确定做流量页后再核对 |
| ohos.permission.GET_WIFI_LOCAL_MAC | 本机WLAN MAC，不能代替邻居MAC权限 | 否；当前无此字段 |
| ohos.permission.ACCESS_NET_TRACE_INFO | 未来API26路由追踪；相关接口还涉及INTERNET及定位授权 | 否；不为未实现功能先申请定位 |

当前包未声明以上四项，也没有对应新功能页面；商店介绍不得先宣传这些能力。完整接口、等级和本机SDK证据见[项目权限说明](../../PERMISSIONS.md)。官网受限权限页面本轮未获得可用正文，具体资格及证明材料以账号下真实申请表和官方审核为准。

## GET_IP_MAC_INFO用途草稿

申请应用名称：木络；包名：com.muge.munet；APP ID、主体、平台要求的证明材料：使用后台真实信息，不填本地调试值。

拟用于用户主动发起的本地网络设备及端口诊断，读取系统邻居缓存中的IP／MAC映射与本机系统端口状态，帮助识别连接对象和定位端口占用。拟在本机展示，不用于广告、位置追踪或用户画像，不上传自营服务器；未授权时保留现有TCP探测并隐藏新增字段。

这是拟新增能力说明，需与最终实现、界面演示及实际保存策略保持一致。当前没有完成版页面或录像，不能用设计稿冒充已经实现。若后台不接受规划功能作为申请依据，应按其要求提供开发验证材料，不虚构现状。

获批后：在新包名应用下确认授权 → 对应调试／发布Profile包含许可 → module声明权限 → 新增接口、拒绝降级及版本判断 → 重新签名安装、真机验证及隐私资料更新。仅加入requestPermissions或让用户点弹窗不能代替系统级受限授权。
