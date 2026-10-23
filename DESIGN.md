# 网络工具箱（NetTools）整体设计

> 2026-10-23 权限复核：本文能力矩阵保留历史实测结果。当前 API 26 SDK 另提供受 GET_IP_MAC_INFO 控制的邻居表／系统端口查询，以及新的网络探测与路由追踪接口；“没有公共 API／普通应用永远拿不到”不作为最新结论。当前版本未接入这些扩展，具体版本、权限和申请边界以[权限清单](docs/PERMISSIONS.md)为准。

> UI重新设计（2026-10-22）：见[整套UI归档](docs/ui-redesign-2026-10-22/README.md)及[完整UI规范](docs/ui-redesign-2026-10-22/UI-SPEC.md)。新文档在视觉、导航和多端布局方面替代下文旧版§3的设计；其状态为设计稿，尚未据此完成整套代码实现。原架构、平台能力与业务实现说明保留。

> 状态：设计评审稿 v2（2026-10-17）
> 平台：HarmonyOS NEXT / OpenHarmony 7.0（API 26），PC 优先，手机/平板自适应
> 架构：**ArkUI（页面/存储/mDNS）+ C++ NAPI 原生核心（探测/扫描，libnettools.so）**
> 依据：SDK 全量 d.ts 核查 + 真机（MateBook Pro HAD-W32，设备 UDID 隐去）
> 实测 + 工信部/华为政策调研（见 §12）

---

## 1. 定位与范围

鸿蒙 PC 上的本地网络诊断工具箱：查看本机网络信息、TCP 连通性测试、端口扫描、
局域网设备发现、扫描历史记录。纯 ArkTS 单 HAP，无账号、无云端、无后台常驻。

**设计原则**

1. **本地优先**：零后端、零数据外传，所有结果只存本机。
2. **诚实可用**：能力边界（TCP ping、无 MAC 列、AP 隔离影响）直接写进 UI
   文案，不假装成 ICMP ping 或 nmap。
3. **轻量**：单 HAP、无 Worker/TaskPool（全事件驱动 IO）、无后台任务。
4. **能 C++ 则 C++**：延迟敏感的探测/扫描/解析下沉到 native 核心
   （`libnettools.so`）；UI、存储、mDNS 等只能用 ArkTS 的留在 ArkTS。

**做**：本机网络信息 / TCP Ping / 端口扫描 / 局域网设备发现 / 历史记录。

**不做（能力边界，非偷懒）**：

- ICMP ping —— 无公共 API，raw socket 需 CAP_NET_RAW，应用沙箱不能 exec
  `/system/bin/ping`（toybox 符号链接，与 dumpcap 无 root 受限同根因）
- MAC 地址列（本机与邻居）—— `GET_WIFI_LOCAL_MAC` / `GET_IP_MAC_INFO` 均
  system_basic，普通开发者证书拿不到
- netstat 式全系统连接列表 —— 纯 ArkTS 无公共 API，应用沙箱也读不到
  `/proc/net/tcp`；要做得加专用 native .so 且可读性未验证，搁置
- 抓包 —— OhShark 已经做了

## 2. 能力矩阵（实证）

| 能力 | API | 权限 | 级别 | 结论 |
|---|---|---|---|---|
| 网卡/IP/网关/DNS/MTU | `connection.getAllNets` + `NetHandle.getConnectionProperties`（since 8） | GET_NETWORK_INFO | normal | ✅ |
| 网络 bearer 类型 | `connection.getNetCapabilities` | GET_NETWORK_INFO | normal | ✅ |
| WiFi 详情 | `wifiManager.getLinkedInfo`（SSID/rssi/band/linkSpeed） | GET_WIFI_INFO | normal | ✅ |
| TCP 连接 | **C++ 原生核心**（POSIX socket，`libnettools.so`）；`@ohos.net.socket` 备选 | INTERNET | normal | ✅ 真机实测 |
| 域名解析 | `connection.getAddressByName` | INTERNET | normal | ✅ |
| mDNS 发现 | `@ohos.net.mdns` `createDiscoveryService`（since 10） | 无 | — | ✅ |
| 持久化 | `@ohos.data.relationalStore`（since 9） | 无 | — | ✅ |
| 剪贴板复制 | `@ohos.pasteboard` | 无 | — | ✅ |
| ARP 邻居表 | `connection.getIpNeighTable`（since 22） | GET_NETWORK_INFO + **GET_IP_MAC_INFO** | **system_basic** | ❌ |
| 本机 MAC | `wifiManager.getDeviceMacAddress`（since 15） | **GET_WIFI_LOCAL_MAC** | **system_basic** | ❌ |
| 流量统计 | `@ohos.net.statistics` | GET_NETWORK_STATS | **system_basic** | ❌ 真机实测 `denied`，普通应用不可用，已放弃 |
| 全系统连接枚举 | 无 | — | — | ❌ 搁置 |
| 本机监听端口 | 原生读取 `/proc/net/tcp[6]`（`listListeningPorts`） | — | — | ❌ 应用沙箱 `denied`；改用本机地址 connect 扫描 |

`TcpConnectOptions` 只有 `address` + `proxy`，**无内建超时**：所有探测要
`setTimeout` 竞速 + 主动 `close`。

## 3. 信息架构与页面设计

单 Ability + `Navigation` 自适应：宽屏（≥ 600vp，PC 主形态）左侧导航栏，
窄屏回退为底部标签导航（均已实现，`onAreaChange` 检测宽度切换）。深浅色跟随
系统。上架版增加「关于」页（已实现）。

### 3.0 通用约定

- 列表一律虚拟滚动（`LazyForEach`），扫描结果增量渲染。
- 系统 API 失败统一走页面顶部错误条（可关闭），不弹窗打断。
- 扫描页统一四区结构：参数区（可折叠）→ 进度区（仅 running）→ 结果区 →
  空态。页面 `aboutToDisappear` 即取消任务。
- 所有「数字/IP」可长按选中或一键复制；PC 上支持鼠标悬停 tooltip。
- 文案规范见附录 C。

### 3.1 本机网络（首页）

```
┌─────────────┬─────────────────────────────────────────────────┐
│ ▣ 本机网络   │  本机网络                              [↻ 刷新]  │
│ ⌁ Ping      │  ┌───────────────────────────────────────────┐  │
│ ⇅ 端口扫描   │  │ ● 已连接   Wi-Fi · wlan0     默认网络      │  │
│ ◎ 局域网     │  │ 192.168.1.23/24     网关 192.168.1.1      │  │
│ ▤ 记录      │  └───────────────────────────────────────────┘  │
│             │  ┌ wlan0 · Wi-Fi · 默认 ─────────────────────┐  │
│  ─────────  │  │ 地址  192.168.1.23/24  [v4]       [复制]   │  │
│ ℹ 关于      │  │ DNS   192.168.1.1 · 223.5.5.5             │  │
│             │  │ MTU   1500   IPv4 ✓   IPv6 ✓              │  │
│             │  │ 搜索域  lan                               │  │
│             │  └───────────────────────────────────────────┘  │
│             │  ┌ WiFi 连接 ────────────────────────────────┐  │
│             │  │ SSID  MyHome   信号 -47 dBm   5 GHz        │  │
│             │  │ 速率  866 Mbps   信道 36                    │  │
│             │  └───────────────────────────────────────────┘  │
└─────────────┴─────────────────────────────────────────────────┘
```

- 数据源：`getAllNets()` 全量网卡；默认网络（`getDefaultNet`）排最前并标
  「默认」；每卡取 `getConnectionProperties` + `getNetCapabilities`。
- 地址列表：`linkAddresses`，每项 IP + `/prefix` + v4/v6 徽标，点击复制。
- 网关：`routes` 中 `isDefaultRoute` 的 `gateway`；DNS：`dnses`。
- WiFi 卡仅当默认网络为 WiFi 时显示（`wifiManager.getLinkedInfo`）。
- **全部网卡卡**：原生 `getifaddrs`（C++）枚举系统全部接口与地址——包括
  NetManager 不暴露为网络的 lo / p2p0 / chba0 及 IPv6 链路本地地址；标注
  回环 / down。为 M3 子网推导提供真实网卡视图。
- 状态：加载中（骨架屏）→ 正常 / 无网络（灰卡「当前无网络连接」）/
  错误条。手动刷新。

### 3.2 Ping（TCP 模式）

```
目标 [ example.com            ]   端口 [80] [443] [22] [3389] [8080]
[✓] 智能回退    次数 [4]   [○ 持续模式]        [开始]  [停止]

example.com → 93.184.216.34
#1  ✓ 12 ms                      10:32:01.204
#2  ✓ 11 ms                      10:32:02.208
#3  ✗ 超时                       10:32:05.213
#4  ✓ 13 ms                      10:32:06.215
发送 4 · 接收 3 · 丢失 25% · avg 12 ms · min 11 · max 13
```

- 端口 chips 默认 80；「智能回退」开启时依次尝试 443→80→22→8080→3389，
  首个成功者记为可达，RTT 取该次连接耗时。
- 次数默认 4；持续模式每 1s 一次直到手动停止（显示滚动统计）。
- 域名先 `getAddressByName` 解析并在标题行展示映射；解析失败只报错不扫描。
- 页面说明文案见附录 C。
- 结果行保留最近 500 条，超出丢弃最旧（持续模式防内存增长）。

### 3.3 端口扫描

```
目标 [ 192.168.1.1 ]   端口集 [常用 40 ▾] [Web ▾] [范围 ▾] [自定义 ▾]
自定义表达式 [ 80,443,1000-2000            ]  并发 [128]  超时 [1500 ms]
                                        [开始扫描]  [停止]

██████████████░░░░░░░░░  1480 / 1560 · 6.2s
端口    服务        RTT
80      http        2 ms
443     https       3 ms
8080    http-proxy  4 ms
（仅列开放端口；关闭/超时共 1557 个）
```

- 端口选择四选一：常用 40 端口（附录 A）/ Web 端口集 / 范围（1–1024、
  1–65535）/ 自定义表达式（`80,443,1000-2000`）。
- **扫描本机**开关：目标切换为本机（127.0.0.1、::1 与所有本机 IPv4 地址），
  逐地址扫描后按端口合并去重，结果标「占用」。`/proc/net/tcp` 在应用沙箱内
  不可读（实测 denied），因此用 connect 扫描近似：覆盖通配绑定与按接口绑定，
  看不到仅绑定 IPv6 的监听，也不显示持有进程。
- 1–65535 与「自定义包含 >4096 个端口」时二次确认（按端口数 × 地址数计算
  探测总数并提示）。
- 结果只列开放端口；closed/timeout 只计数不渲染。
- 进度：done/total + 已用时间；停止 → 状态 `cancelled`，仍展示已完成结果。
- 结束后写 `scan_record`（summary 含开放端口数与耗时）。

### 3.4 局域网发现

```
范围 [ 192.168.1.0/24 ]  (wlan0)   [开始发现]  [停止]
███░░░░░░░░░░░░░░  38 / 254 · 3.1s

IP              状态   端口              主机名
192.168.1.1     ● 在线 80,443            router.lan
192.168.1.23    ● 在线 22                (本机)
192.168.1.100   ● 在线 445,3389          nas
192.168.1.50    ○ 未响应 —               —
```

- 范围从**默认网络**的 `linkAddresses` 推导（避免误用 chba0 等辅助网段），
  可手改 CIDR；IPv4 且 prefix ≤ 30 才可扫；IPv6 禁用并说明。
- 探测：每主机端口组 [80, 443, 22, 445, 3389, 8080]，任一成功即在线、
  记录命中端口；并发 128、超时 1000ms。
- mDNS 与 sweep 并行：按 IP 归并主机名（服务类型见附录 B）。
- 结果行与 `discovered_host` upsert 合并，显示首次/最近发现时间。
- 页面说明：AP 隔离环境下部分设备不可见（附录 C）。

### 3.5 记录

- 双视图页签：**扫描记录** / **设备档案**
- 扫描记录：时间 / 类型 / 目标 / 摘要两行展示；「再扫」跳转对应页面并回填
  目标（壳层导航）；按类型筛选；CSV/JSON 导出（系统文件选择器）；清空
  （确认弹窗，同时清空档案）
- 设备档案：`discovered_host` 列表（IP、mDNS 名、命中端口、最近发现时间），
  由局域网发现结果 upsert 维护

### 3.6 关于（上架版必需）

- 版本号、隐私政策入口（AGC 隐私托管 URL）、免责声明（附录 C）。
- 若将来备案：展示备案号并链接 `https://beian.miit.gov.cn`（105 号文强制）。

## 4. 技术架构

### 4.1 架构总则（MVVM + 单向数据流）

#### 4.1.1 分层与职责

| 层 | 目录 | 职责 | 约束 |
|---|---|---|---|
| View | `pages/`、`views/` | 声明式渲染、转发用户事件、一次性 UI 反馈（toast） | 只能 import `viewmodel/` 与 `model/`；不含业务判断、数据加工、系统 API 调用 |
| ViewModel | `viewmodel/` | 页面状态、异步编排、错误处理、展示格式化、动作方法 | 只能 import `repository/` 与 `model/`；不 import ArkUI 组件、`net/`、`store/`、`services/`、native |
| Repository | `repository/` | 用例级数据聚合：组合多个数据源、归一化结果、屏蔽系统细节 | 不 import View/VM；不含 UI 状态 |
| Data Source | `net/`、`services/`、`store/` | 系统网络 API、C++ 原生核心、平台服务、持久化 | 一个文件只封装一类能力；不 import 上层 |
| Model | `model/` | 纯数据类型（interface / type / enum），无行为 | 不 import 任何其他层 |

#### 4.1.2 依赖规则

| ↓ 依赖 / 被依赖 → | model | repository | viewmodel | views | data source |
|---|---|---|---|---|---|
| model | — | ❌ | ❌ | ❌ | ❌ |
| repository | ✅ | — | ❌ | ❌ | ✅ |
| viewmodel | ✅ | ✅ | — | ❌ | ❌ |
| views | ✅（仅类型） | ❌ | ✅ | — | ❌ |
| data source | ✅ | ❌ | ❌ | ❌ | — |

硬性规则：

1. 依赖单向：`View → ViewModel → Repository → Data Source`；Model 被引用但
   不依赖任何层。
2. **native（`libnettools.so`）只允许在 `net/NativeCore.ets` 内 import**，
   其余代码一律经 Repository。
3. 系统能力统一用 `@kit.*` 导入（禁止 `@ohos.*` 直导）。
4. 反向 import 一律视为评审不通过。

#### 4.1.3 状态管理与数据流

- VM 用 `@Observed` 装饰，View 以 `@State vm: XxxViewModel` 持有；属性变更
  驱动重渲染。数组整体赋值；嵌套对象元素更新后续用 `@ObjectLink`。
- VM 状态分四组：`isLoading` / `error` / 业务数据 / 派生展示字段
  （状态卡文案等）。
- 数据流严格单向：View 事件 → VM 动作 → Repository/数据源 → VM 状态 →
  重渲染。
- 壳层 UI 状态（当前导航项）属于 View；页面业务状态一律在 VM。
- 一次性效果（toast、后续页面跳转）由 View 在动作 Promise 返回后触发；
  VM 不持有 UI 句柄、不弹 toast。

#### 4.1.4 生命周期与并发取消

- View `aboutToDisappear` → `vm.leave()`；VM 置位运行标志并调用
  `Repository.cancel()`。页面 `aboutToAppear` 负责初始加载/回填。
- 取消机制：C++ 侧 `cancelScan()` 递增代际计数，在飞任务检测到代际变化即
  停止，已完成结果照常返回；ArkTS 侧以 VM 的 `isRunning` / `cancelled` 标志
  截止循环。未引入额外的 CancelToken 对象。
- 批量探测下沉 C++（`scanPorts` / `sweepCidr`），ArkTS 只做调度与渲染。
- VM 动作可从事件处理里 fire-and-forget；异常必须在 VM 内收敛，禁止抛给
  View。

#### 4.1.5 错误处理

- Data Source 抛原始错误（BusinessError 等）；Repository 透传或归一化；
  VM 捕获后写 `error` 字段（用户可读文案），并尽量保留可展示的降级数据。
- View 只渲染错误条，不判断错误类型。
- 错误日志用 hilog，tag 固定 `NetTools`，不打印敏感数据。

#### 4.1.6 依赖注入与可测试性

- VM 构造函数注入 Repository，默认参数创建真实实现：
  `constructor(repo: LocalNetRepository = new LocalNetRepository())`。
- ohosTest 用 Fake Repository 实例化 VM，断言状态迁移，不需要真机网络；
  测试命名 `XxxViewModel.test.ets`。当前已覆盖纯模块
  （`Subnet` / `HistoryExportFormat`，6 个用例），VM fake 用例待补。
- Repository 方法即 mock 边界。

#### 4.1.7 导航与页面装配

- `pages/Index.ets` 是唯一路由页，负责导航壳与 View 装配；View 之间不
  互相跳转。
- 上架版增加 `AboutView`（隐私政策 / 版本 / 备案号）。

#### 4.1.8 新增页面 checklist

1. `model/` 定义领域类型（新领域新建文件）。
2. 数据源：`net/`、`services/`、`store/` 实现；原生能力只进 `net/NativeCore.ets`。
3. `repository/XxxRepository.ets` 聚合数据源（可注入 fake）。
4. `viewmodel/XxxViewModel.ets`：`@Observed`、构造注入、状态四组、动作方法、
   错误收敛。
5. `views/XxxView.ets`：`@State vm`、纯渲染、`onXxx` 转发。
6. `pages/Index.ets` 装配。
7. 干净构建 + 真机截图/OCR 验证。

### 4.2 工程结构与命名规范

```
nettools/                          ← 独立仓库（与 thirty/ 平级）
├── AppScope/
├── entry/src/main/
│   ├── ets/
│   │   ├── entryability/
│   │   │   ├── EntryAbility.ets
│   │   │   └── DebugSmokeRunner.ets # 调试构建无头冒烟（Want 参数驱动）
│   │   ├── pages/Index.ets        # 路由壳：导航态 + View 装配
│   │   ├── views/                 # View 层（纯渲染）
│   │   │   ├── LocalNetView.ets
│   │   │   ├── PingView.ets       # M2
│   │   │   ├── PortScanView.ets   # M2
│   │   │   ├── LanDiscoveryView.ets # M3
│   │   │   ├── HistoryView.ets    # M3
│   │   │   ├── AboutView.ets      # 上架版
│   │   │   └── ErrorBanner.ets    # 共享错误条组件
│   │   ├── viewmodel/             # ViewModel 层（@Observed）
│   │   │   ├── LocalNetViewModel.ets
│   │   │   ├── PingViewModel.ets
│   │   │   ├── PortScanViewModel.ets
│   │   │   ├── LanDiscoveryViewModel.ets
│   │   │   ├── HistoryViewModel.ets
│   │   │   └── DebugViewModel.ets
│   │   ├── repository/            # Repository 层
│   │   │   ├── LocalNetRepository.ets
│   │   │   ├── ScanRepository.ets
│   │   │   ├── DiscoveryRepository.ets
│   │   │   ├── HistoryRepository.ets
│   │   │   ├── ClipboardRepository.ets
│   │   │   └── SystemRepository.ets
│   │   ├── model/                 # 纯类型（按领域一个文件）
│   │   │   ├── NetworkInfo.ets    # LinkAddr/NicInfo/WifiInfo/IfaceInfo/ProbeResult/IfaceTraffic
│   │   │   ├── ScanInfo.ets       # PortResult/HostResult/ListeningPort/PingRecord/PingStats/PortScanMode
│   │   │   └── HistoryInfo.ets    # ScanRecord/DiscoveredHost/ScanKind/ScanStatus/ExportFormat
│   │   ├── net/                   # Data Source：系统网络 / 原生核心
│   │   │   ├── NativeCore.ets     # ★ 唯一 import libnettools.so 的文件
│   │   │   ├── LocalNetInfo.ets   # connection / wifiManager
│   │   │   ├── MdnsDiscovery.ets  # mDNS 会话（best-effort）
│   │   │   ├── Subnet.ets         # CIDR 推导 / 主机数
│   │   │   ├── PortPresets.ets    # 常用/Web/sweep 端口集
│   │   │   └── ServiceNames.ets   # 端口→服务名表
│   │   ├── services/              # 平台服务
│   │   │   ├── Clipboard.ets
│   │   │   ├── HistoryExportFormat.ets # 纯序列化（CSV/JSON，可单测）
│   │   │   └── HistoryExporter.ets # picker + fileIo
│   │   ├── store/HistoryStore.ets # relationalStore（两张表）
│   │   └── （无 common/：取消由原生代际计数 + VM 标志承担）
│   ├── cpp/                       # ★ 原生核心（C++ / NAPI）
│   │   ├── CMakeLists.txt
│   │   ├── napi_init.cpp          # probeTcp / listInterfaces / version（§4.4）
│   │   └── types/libnettools/     # d.ts + oh-package（ArkTS 类型解析）
│   ├── module.json5               # 权限：INTERNET + GET_NETWORK_INFO + GET_WIFI_INFO
│   ├── resources/
│   └── ohosTest/                  # hypium 单元测试（Subnet / 导出序列化）
└── hvigor 配置
```

#### 4.2.1 命名规范

**目录**：全小写单数，按层命名：`pages` `views` `viewmodel` `repository`
`model` `net` `services` `store` `common`。功能多了再按领域建子目录，此前
保持单层扁平。

**文件**

| 类别 | 规则 | 示例 |
|---|---|---|
| View / ViewModel / Repository | PascalCase，与主导出符号同名 | `LocalNetView.ets`、`LocalNetViewModel.ets`、`LocalNetRepository.ets` |
| Model | 按领域一个文件，PascalCase | `model/NetworkInfo.ets`、`model/ScanInfo.ets` |
| Data Source | 按封装对象命名 | `LocalNetInfo.ets`、`NativeCore.ets`、`HistoryStore.ets`、`Clipboard.ets` |
| 页面入口 | 固定 | `pages/Index.ets`（`main_pages.json` 引用） |
| 测试 | `Xxx.test.ets` | `LocalNetViewModel.test.ets` |

**类型**

- interface / class：PascalCase 名词，**不加 `I` 前缀**（`NicInfo`、`HostResult`）。
- enum：PascalCase；成员 `UPPER_SNAKE`（`ScanKind.PORT_SCAN`）。
- 布尔字段：`is` / `has` / `can` 前缀（`isLoading`、`isConnected`、`hasGateway`）。

**成员与方法**

- 字段：camelCase 名词；量值带单位后缀（`rttMs`、`timeoutMs`、`mtu`）。
- 方法：动词开头。异步取数 `fetchXxx`；同步读取 `readXxx`；持久化
  `add` / `update` / `query` / `delete`；动作 `load` / `refresh` / `start` / `stop` / `copy`。
- VM 动作返回 `Promise<boolean>` 表示成功/失败；状态只由动作更新。
- 私有成员加 `private`，**不加下划线前缀**（`private readonly repo`）。

**事件处理（View）**：`onXxx`（`onRefresh`、`onCopy`、`onDismissError`）；
回调只调 VM / 平台服务，不写业务逻辑。

**常量**：模块级 `UPPER_SNAKE_CASE`（`BEARER_LABELS`）；局部常量 camelCase；
默认值与魔法数集中声明，禁止散落。

**C++ / NAPI**：导出函数 camelCase（`probeTcp`、`listInterfaces`；规划
`scanPorts`、`sweepCidr`）；内部函数与结构体 PascalCase；常量 `kPascalCase`；
文件名 snake_case（`napi_init.cpp`，后续按职责拆 `probe.cpp` / `ifaces.cpp`）；
`d.ts` 与实现同名同形。

**资源**：用户可见静态文案进 `resources/base/element/string.json`
（key `snake_case`）；动态文案在 VM 组装。M1 文案暂硬编码，M2 起新页面
遵守，M1 后续回填。

**导入**：顺序 = 系统 `@kit.*` → model 类型 → 本层依赖；禁止跨层反向相对
路径（如 `views/` 不得 import `net/`）。

**文档**

- 非平凡文件以块注释说明职责边界：model、net、repository、store、services、
  entryability；View/ViewModel 以组件/类文档为准。
- 导出的类型、函数、方法用一句话说明契约（输入、返回、异常与空值语义），
  不复述代码本身。
- 注释只解释「为什么/约束」，实现细节交给命名表达。
- 行为或接口变更必须同步 README / DESIGN；文档是本项目的验收项之一。

### 4.3 核心机制

**TcpProbe（唯一探测原语，C++ 实现）**

```
libnettools.probeTcp(host, port, timeoutMs) → { ok, rttMs, error }
  C++：getaddrinfo → 非阻塞 socket → connect/poll 竞速 → 记 RTT/错误 → close
```

单次探测在 native 层完成（每次新建 socket，不复用）。Ping / 端口扫描 /
子网 sweep 全部复用。并发批处理 `scanPorts` / `sweepCidr` 已在 C++ 内完成
（§4.4），ArkTS 只负责调度与渲染。

**取消机制（原生代际计数 + VM 标志）**

- `cancelScan()` 递增 C++ 侧代际计数，在飞 worker 检测到代际变化即停止；
  已完成结果仍随 Promise 返回（取消后只展示已探测部分）。
- ArkTS 侧 VM 以 `isRunning` / `cancelled` 截止循环；页面
  `aboutToDisappear` 调用 `vm.leave()`。
- 进度通过 ThreadSafeFunction 节流回传 `(done, total)`，耗时由 UI 自行计算。

**数据流**：单向。`net/` 产出 → 页面 `@State` 渲染 → `store/` 按需持久化。
无全局状态管理，跨页共享的只有发现记录（走 store 查询）。

**线程模型**：全部 async IO（socket/mdns 事件驱动），主线程即可，
不需要 TaskPool/Worker。

### 4.4 接口契约

**Model（`model/*.ets`，纯类型）**

```ts
export interface LinkAddr { address: string; prefixLength: number; family: string }
export interface NicInfo {
  netId: number; interfaceName: string; bearerTypes: string[]; isDefault: boolean;
  linkAddresses: LinkAddr[]; gateway: string; dns: string[]; domains: string;
  mtu: number; ipv4Valid: boolean | undefined; ipv6Valid: boolean | undefined;
}
export interface WifiInfo { ssid: string; rssi: number; band: number;
                            frequency: number; linkSpeed: number }
export interface IfaceInfo { name: string; address: string; family: string;
                             prefixLength: number; loopback: boolean; up: boolean }
export interface ProbeResult { ok: boolean; rttMs: number; error: string }
export interface IfaceTraffic { rxBytes: number; txBytes: number }

export interface PortResult { port: number; open: boolean; rttMs: number; error: string }
export interface HostResult { ip: string; online: boolean; openPorts: number[] }
export interface ListeningPort { port: number; address: string; family: string; uid: number }
export interface PingRecord { seq: number; ok: boolean; rttMs: number; error: string;
                              port: number; timestamp: number }
export interface PingStats { sent: number; received: number; lossPercent: number;
                             avgMs: number; minMs: number; maxMs: number }
export enum PortScanMode { COMMON = 'common', WEB = 'web',
                           TOP1024 = 'top1024', CUSTOM = 'custom' }

export enum ScanKind { PING = 'ping', PORT_SCAN = 'portscan',
                       LAN_DISCOVERY = 'landiscovery' }
export enum ScanStatus { DONE = 'done', CANCELLED = 'cancelled', ERROR = 'error' }
export enum ExportFormat { CSV = 'csv', JSON = 'json' }
export interface ScanRecord { id: number; ts: number; kind: ScanKind; target: string;
                              status: ScanStatus; summary: string }
export interface DiscoveredHost { ip: string; firstSeen: number; lastSeen: number;
                                  hostname: string; openPorts: number[] }
```

**Repository（UI 唯一的数据入口）**

```ts
// LocalNetRepository
async fetchNics(): Promise<NicInfo[]>
async fetchWifiInfo(): Promise<WifiInfo | null>
readInterfaces(): IfaceInfo[]
async resolveAddress(host: string): Promise<string>
async defaultCidr(): Promise<string>
hostCount(cidr: string): number

// ScanRepository
commonPorts(): number[]; webPorts(): number[]; sweepPorts(): number[]
parsePorts(expr: string): number[]
serviceName(port: number): string
readLocalListeningPorts(): ListeningPort[] | null
localScanTargets(): string[]
async scan(host: string, ports: number[], concurrency: number, timeoutMs: number,
           onProgress: (done: number, total: number) => void): Promise<PortResult[]>
async sweep(cidr: string, ports: number[], concurrency: number, timeoutMs: number,
            onProgress: (done: number, total: number) => void): Promise<HostResult[]>
cancel(): void

// DiscoveryRepository
startMdns(context: common.Context): void
stopMdns(): Map<string, string>
sweepPorts(): number[]; sweep(...); cancel()

// HistoryRepository
async initialize(context: common.Context): Promise<void>
isReady(): boolean
async addScanRecord(record: ScanRecord): Promise<void>
async queryScanRecords(): Promise<ScanRecord[]>
async upsertHosts(hosts: HostResult[], names: Map<string, string>): Promise<void>
async queryHosts(): Promise<DiscoveredHost[]>
async exportHistory(context: common.Context, format: ExportFormat): Promise<boolean>
async clearAll(): Promise<void>

// ClipboardRepository
async copy(text: string): Promise<boolean>

// SystemRepository
coreVersion(): string
probeSelfTest(): string
async ifaceTraffic(nic: string): Promise<IfaceTraffic | null>
```

**原生核心 `libnettools.so`（v0.3.0 已实现）**

```ts
export interface ProbeResult { ok: boolean; rttMs: number; error: string }
export interface IfaceInfo   { name: string; address: string; family: string;
                               prefixLength: number; loopback: boolean; up: boolean }
export interface PortResult  { port: number; open: boolean; rttMs: number; error: string }
export interface HostResult  { ip: string; online: boolean; openPorts: number[] }

export const version: () => string;
export const probeTcp: (host: string, port: number, timeoutMs: number) => ProbeResult;
export const listInterfaces: () => IfaceInfo[];
export const parsePortExpr: (expr: string) => number[];
export const scanPorts: (host: string, ports: number[], concurrency: number,
  timeoutMs: number,
  onProgress: (done: number, total: number) => void) => Promise<PortResult[]>;
export const sweepCidr: (cidr: string, ports: number[], concurrency: number,
  timeoutMs: number,
  onProgress: (done: number, total: number) => void) => Promise<HostResult[]>;
export const listListeningPorts: () => ListeningPort[] | null;
export const cancelScan: () => void;
```

`listListeningPorts` 解析 `/proc/net/tcp[6]` 的 LISTEN 项（含绑定地址与 UID），
但应用沙箱拒绝访问该路径，当前仅作为其他设备/后续版本的快速路径保留；
「扫描本机」实际使用 connect 扫描。

`scanPorts` / `sweepCidr` 在 C++ 内完成并发调度（native 线程池 + 非阻塞
connect/poll），进度经 ThreadSafeFunction 节流回传；`cancelScan` 通过代际
计数取消在飞任务，已完成结果仍会返回（取消后仅展示已探测部分）。扫描结果
按输入顺序返回（含关闭/超时原因），由 ArkTS 过滤。`sweepCidr` 支持
/31、/32；前缀小于 16（超过 65536 主机）直接返回空结果，由 UI 侧校验与
确认。

### 4.5 参数与性能预算

| 参数 | 默认 | 可调范围 | 位置 |
|---|---|---|---|
| Ping 超时 | 2000 ms | 500–5000 | Ping 页 |
| 端口扫描超时 | 1500 ms | 500–5000 | 端口扫描页 |
| sweep 超时 | 1000 ms | 固定常量 | DiscoveryRepository |
| 端口扫描并发 | 128 | 10–512 | 端口扫描页 |
| sweep 并发 | 128 | 固定常量 | DiscoveryRepository |
| sweep 端口组 | 80,443,22,445,3389,8080 | 固定常量 | DiscoveryRepository |
| Ping 次数 | 4 | 1–999 | Ping 页 |
| 持续 ping 间隔 | 1000 ms | 200–5000 | Ping 页 |
| 大子网确认阈值 | 1024 主机 | 固定常量 | 页面 |
| 结果列表上限 | 500 行 | — | 页面 |

性能预算（最坏情况，实测后调参）：

- `/24` sweep 实测：254 主机 × 6 端口，12.1s（真机）。
- 1–65535 端口扫描：65535 次探测，128 并发 × 1.5s → 约 12.8 min（必须二次
  确认 + 可停止 + 进度显示）。
- 结果数组在 C++ 侧按端口数分配（65535 项约 1MB）；ArkTS 只保留开放端口，
  列表虚拟滚动。

### 4.6 页面状态机

```
idle → running → done | cancelled | error
        ↑            │
        └── 再扫一次 ─┘        running 中可「停止」；离开页面强制 cancel
Ping 持续模式：running 直到手动停止（不自动 done）
```

## 5. 数据模型

```sql
CREATE TABLE scan_record (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  ts      INTEGER NOT NULL,        -- epoch ms
  kind    TEXT NOT NULL,           -- 'ping' | 'portscan' | 'landiscovery'
  target  TEXT NOT NULL,           -- host / host:ports / cidr
  status  TEXT NOT NULL,           -- 'done' | 'cancelled' | 'error'
  summary TEXT NOT NULL            -- JSON：丢包率/avg RTT/开放端口/在线数…
);
CREATE INDEX idx_scan_ts   ON scan_record(ts DESC);
CREATE INDEX idx_scan_kind ON scan_record(kind, ts DESC);

CREATE TABLE discovered_host (
  ip         TEXT PRIMARY KEY,
  first_seen INTEGER NOT NULL,
  last_seen  INTEGER NOT NULL,
  hostname   TEXT,                 -- mDNS 名，可空
  open_ports TEXT NOT NULL         -- JSON 数组
);
```

- `summary` 示例：`{"sent":4,"recv":3,"loss":25,"avg":12,"min":11,"max":13}` /
  `{"open":[80,443,8080],"elapsedMs":6200}` / `{"online":12,"total":254,"cidr":"192.168.1.0/24"}`
- 记录上限 500 条，插入后超出删最旧；`discovered_host` 永久 upsert
  （`last_seen`/`hostname`/`open_ports` 更新，`first_seen` 保留）。
- 初始化在 EntryAbility `onCreate`，失败时记录页禁用并提示。

## 6. 权限清单

| 权限 | 级别 | 授权方式 | 用途（隐私政策措辞） |
|---|---|---|---|
| ohos.permission.INTERNET | normal | system_grant | 网络探测（TCP 连接测试、端口扫描） |
| ohos.permission.GET_NETWORK_INFO | normal | system_grant | 读取本机网卡、路由、DNS 信息 |
| ohos.permission.GET_WIFI_INFO | normal | system_grant | 显示 WiFi 连接详情 |

无需运行时弹窗。不申请 location（不用 WiFi 扫描列表）。隐私政策中声明的
权限必须与 `module.json5` 完全一致（AGC 硬校验）。

## 7. 错误处理与边界

| 场景 | 表现 | 文案 |
|---|---|---|
| `getDefaultNet()` 为空 | 首页灰卡，各页禁用 | 当前无网络连接 |
| BusinessError 2100002/2100003 | 顶部错误条 | 网络服务暂不可用，请稍后重试 |
| DNS 解析失败 | Ping 结果区 | 无法解析域名，请检查目标或网络 |
| connect 拒绝 | 结果行 | 拒绝连接 |
| probe 超时 | 结果行 | 超时 |
| 端口表达式非法 | 输入框下红字 | 格式示例：80,443,1000-2000 |
| 子网 > 1024 主机 | 确认弹窗 | 该网段含 N 台主机，扫描可能较慢，继续？ |
| 扫描中离开页面 | 自动取消 | 记录状态 `cancelled` |
| mDNS 无结果 | 正常空态 | 未发现 mDNS 服务（不影响 IP 发现） |
| 存储初始化失败 | 记录页禁用 | 本地存储不可用，历史记录功能已停用 |

其它边界：

- 多网卡并存（真机 wlan0 + chba0）：全列出，默认网络标记排序；sweep 只用
  默认网络的子网。
- IPv6：Ping 支持（地址直填）；sweep 不支持（禁用并说明）。
- 端口输入校验：1–65535；区间起止相反、空表达式、非法字符均行内提示。

## 8. 工程参数与命名

- **应用名：待定，必须品牌化**（"网络工具箱"这类类别词会被商店名称规则与
  备案规则驳回，见 §12）。候选（需在 AGC 创建应用时查重，并查商标）：

  | 候选 | 英文 | 意象 |
  |---|---|---|
  | 网镜 | Netscope | 透视网络 |
  | 网迹 | NetTrace | 追踪网络痕迹 |
  | 探针盒子 | ProbeBox | 工具感 |
  | 鲨眼 | SharkEye | 与 OhShark 品牌呼应 |

- bundle：`com.munet.app`（可改；若改名，包名不必跟随，但备案/软著需一致
  的是应用名，不是包名）。
- DevEco 标准工程，单 entry 模块（规模不需要 HAR 拆分）。
- compatibleSdkVersion `6.0.2(22)`，targetSdkVersion `26.0.0`（实测 API 22
  平板可安装运行；`getConnectionProperties` 等所需 API 在 22 上均可用）。
- 真机验证沿用 OhShark 纪律：截图 + OCR 为准，不只看日志。

## 9. 开发与验证流水线

1. **依赖**：`ohpm install --all`（`libnettools.so` 以
   `"libnettools.so": "file:./src/main/cpp/types/libnettools"` 声明，
   名字必须与类型包 `name` 一致，否则 ArkTS 侧导入退化为 any 并编译失败）。
   构建产物同时包含 `arm64-v8a` 与 `x86_64`（后者用于模拟器验证）。
2. **构建**：`./hvigorw assembleHap --mode module -p product=default debuggable`
   （`DEVECO_SDK_HOME` 指向 DevEco `sdk` 目录，node 用 DevEco 自带）。
3. **⚠️ 干净构建**：首次构建若 CompileArkTS 失败过，后续增量打包可能产出
   **没有 `ets/modules.abc` 的 HAP**（真机症状：`JsRuntime: run script
   failed`、`null jsAbilityObj`、永久卡启动图）。改过 ets 或首次失败后，
   先 `rm -rf entry/build .hvigor` 再构建，并 `unzip -l` 确认包含
   `ets/modules.abc`。
4. **签名**：`bash ../thirty/tools/sign-local.sh <unsigned.hap> <out.hap> <UDID>
   com.munet.app`（脚本与材料位于同级 thirty 工作区，不入本仓库；profile
   按 UDID + bundleName 动态生成；开发期也可用 AGC 自动签名）。
   **每个设备 UDID 需单独签一次**。
5. **部署**：`hdc -t <UDID> install -r <hap>` →
   `aa start -a EntryAbility -b com.munet.app -m entry`。
6. **无头冒烟（调试构建，仅 BuildProfile.DEBUG 生效）**：设备被其他窗口占用
   时不必抢前台，用 Want 参数直接跑原生核心并把结果打到 hilog：
   - 批量扫描：`aa start ... --ps netprobe.host <ip> --ps netprobe.ports 80,443,1000-2000`
   - Ping VM：`aa start ... --ps netprobe.ping.host <ip> --ps netprobe.ping.port 443 --ps netprobe.ping.count 3`
   - 子网 sweep：`aa start ... --ps netprobe.sweep.cidr 192.168.1.0/24`
     （可选 `--ps netprobe.sweep.ports 80,443`）
   - 历史查询：`aa start ... --ps netprobe.history 1`
   - 读取：`hilog -x | grep 'headless'`（tag `NetTools`）
7. **单元测试（ohosTest / hypium）**：

   ```bash
   ./hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap
   bash ../thirty/tools/sign-local.sh entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap \
       entry-ohosTest-signed.hap <UDID> com.munet.app
   hdc -t <UDID> install -r entry-ohosTest-signed.hap
   hdc -t <UDID> shell "aa test -b com.munet.app -m entry_test \
       -s unittest OpenHarmonyTestRunner -s timeout 60000"
   ```

   结果看 `OHOS_REPORT_RESULT: Tests run: N, Failure: 0, Error: 0`。
8. **验证（优先 MCP，比手搓 hdc 快）**：
   - `build_app` / `install_app` / `run_app` / `screenshot` / `get_ui_tree` /
     `click` / `swipe` / `input_text` / `logs_query`。
   - 网络类结论必须在**真机真实网络环境**下验证（模拟器无意义）。
   - 本机信息页与 `hdc shell ifconfig` / `ip addr` 对照核对 IP/网关/DNS。
   - 任何 UI 结论以截图 + OCR（必要时像素探针）+ 真实注入点击为准。
9. **日志**：`hilog` 过滤应用 tag；错误路径必须打点（不打印敏感地址全文，
   打掩码）。

## 10. 里程碑与验收矩阵

| 阶段 | 内容 | 验收（真机实测步骤） |
|---|---|---|
| M1 | 工程骨架 + 本机网络页 | 打开应用显示真实网卡；与 `hdc shell ifconfig` 核对 IP/网关/DNS 一致；点 IP 复制后可粘贴；断网重开显示降级态 |
| M2 | Ping + 端口扫描 | ping 网关成功且 RTT 合理；ping 不存在 IP 超时；对路由器扫 1–1024 至少发现 80/443；扫描中点停止 → 状态正确；大端口范围二次确认生效 |
| M3 | 局域网发现 + 记录 | sweep 当前 /24 发现网关 + ≥1 台真实设备；mDNS 名归并（有则显示）；重启应用记录仍在；离线时各页降级正确 |
| M4 | 打磨 | 导出 CSV/JSON；键盘快捷键；流量统计（若 GET_NETWORK_STATS 真机验证通过，否则砍掉）；关于页与合规配置 |

## 11. 风险与待验证

| 项 | 风险 | 对策 |
|---|---|---|
| sweep 耗时 | /24 最坏约 12s 偏慢 | M3 实测后调并发/超时/端口组 |
| mDNS 产出稀疏 | PC/路由器服务少，可能几乎为空 | 定位为增强项，sweep 为主发现手段 |
| GET_NETWORK_STATS 后端强制 | 流量统计被拒 | M4 才做，被拒就砍，无依赖 |
| 端口扫描被路由器安全策略干扰 | 部分端口误判 | 超时可调 + 结果页说明 |
| 子网推导遇到多 IP/ppp 等非常规网卡 | 推导错误 | 以默认网络为准 + 允许手改 CIDR |
| 鸣谢/隐私链接失效 | 提审被拒 | 关于页固定 AGC 托管 URL，上线前逐项核对 |

## 12. 分发与合规（2026-10 审视）

**结论：本应用无后端服务器、不向用户提供互联网信息服务（只是用户主动发起
的诊断探测），按华为官方口径属"单机 APP"，上架大概率不需要工信部备案。**
判定标准不是"连不连公网"，而是"是否通过连接公网**提供**互联网信息服务"
（华为定义，见《APP核准（APP备案）指引》）。有官方工单先例：单机应用收到
备案提醒邮件属误发，官方答复"不用备案"。注意：工信部 105 号文本身无单机
豁免成文条款，"单机免备案"是执行层口径，最终以 AGC 审核认定为准；若将来
加入任何连自家服务器的功能（云同步等），即触发备案义务。

### 分发路径决策树

| 路径 | 备案 | 其他要求 |
|---|---|---|
| 自用侧载（hdc + 本地签名，现行 OhShark 路线） | 不需要 | 开发者模式；纯净模式"增强防护"会拦截侧载；安装时可能提示"备案状态未知" |
| 指定设备发布（≤100 台，AGC） | 不需要 | 实名开发者账号；不经应用市场分发，无上架审核 |
| 邀请测试 / 公开测试 / 正式上架 | 单机 APP 免备案（表单声明）；公开测试明确要求备案 | 隐私政策 + 版权信息 + 上架审核 |

### 上架必备清单（比备案更实际的四件事）

1. **名称（最大坑）**：官方名称规则禁止"广义归纳、不具辨识性"的类别词
   （官方反例："手机定位、手电筒"），「网络工具箱」必被驳回；若走备案，
   备案名 = 上架名 = 软著名三处一致。见 §8 候选。
2. **隐私政策**：必须提供（零收集也要），AGC 隐私托管可自动生成。
   **硬校验：隐私政策声明的权限必须与 module.json5 完全一致，否则无法提审**。
   用途措辞见 §6。
3. **版权信息**：软著/电子版权证书，个人可用华为模板《免责函》替代；
   仅游戏强制软著+版号。
4. **类目与措辞**：工具类允许个人发布（华为是少数仍完全开放个人开发者的
   商店）；个人不能发布到中国大陆以外区域。定位写"网络诊断"，避开
   Wi-Fi 管理/检测/提速（3.7 饱和类目）；避开"扫描他人/破解/蹭网/监控"
   字眼，强调"自有网络环境内诊断"。3.14 要求 IPv6 环境可正常运行
   （Ping 已支持 v6）。
5. **HarmonyOS PC 通道（最大不确定项）**：鸿蒙 PC 应用生态 2025 年起主要
   面向企业开发者，个人开发者上架 PC 端的开放程度无官方明文。
   行动项：agconnect@huawei.com 邮件确认。备选：先上手机/平板版
   （UI 本就自适应），PC 自用侧载（鸿蒙电脑支持侧载）。

上架版本需启用「关于」页（§3.6）：隐私政策入口；若将来备案则展示备案号并
链接 beian.miit.gov.cn（105 号文强制要求）。

### 若将来需要备案（加入云端功能时）

- 通道：云服务商备案系统（华为云/阿里云/腾讯云），个人主体可办，备案本身免费
- 前置：包月 ≥3 个月的大陆节点云服务器（约百元/年）+ 实名域名（几十元/年）
  + 身份证 + 人脸核验；时效 3–22 个工作日
- 依据：工信部信管〔2023〕105 号（2023-08 发布，2024-04 起应用市场强制）；
  华为《APP核准（APP备案）指引》 developer.huawei.com/consumer/cn/doc/app/50130

## 附录 A 常用端口 → 服务名

```
21 ftp · 22 ssh · 23 telnet · 25 smtp · 53 dns · 80 http · 110 pop3 ·
111 rpcbind · 135 msrpc · 139 netbios-ssn · 143 imap · 443 https · 445 smb ·
465 smtps · 587 submission · 993 imaps · 995 pop3s · 1433 mssql · 1521 oracle ·
2049 nfs · 2181 zookeeper · 3000 dev-ui · 3306 mysql · 3389 rdp · 5432 postgres ·
5900 vnc · 6379 redis · 7001 weblogic · 8000 http-alt · 8080 http-proxy ·
8081 http-alt · 8443 https-alt · 9000 php-fpm · 9090 http-alt ·
9200 elasticsearch · 11211 memcached · 27017 mongodb
```

未收录端口显示 —。

## 附录 B mDNS 服务类型

```
_http._tcp  _https._tcp  _ssh._tcp  _smb._tcp  _ipp._tcp  _ipps._tcp
_airplay._tcp  _raop._tcp  _googlecast._tcp  _device-info._tcp
_companion-link._tcp  _workstation._tcp
```

## 附录 C  UI 文案规范

**Ping 页说明**：

> TCP 探测（非 ICMP）：向目标端口发起连接并计时。端口关闭或防火墙拦截会
> 显示超时/拒绝，不代表主机离线。可开启"智能回退"自动尝试多个常用端口。

**局域网页说明**：

> 仅扫描你当前所在网段。若路由器开启了 AP 隔离，部分设备可能不可见。

**关于页免责声明**：

> 本工具仅用于诊断自有或经授权的网络。请勿对未经授权的网络或设备进行
> 探测。

**空态/状态文案**：

| 场景 | 文案 |
|---|---|
| 无记录 | 暂无记录，扫描完成后会出现在这里 |
| 无发现 | 未发现在线设备；若确认网段正确，可能是路由器开启了 AP 隔离 |
| 无网络 | 当前无网络连接 |
| 扫描中 | 正在探测…（可随时停止） |
| 已取消 | 已取消，以下为已完成部分的结果 |
| 无开放端口 | 未发现开放端口（共扫描 N 个） |

## 附录 D 设计决策记录（ADR）

| # | 决策 | 理由 |
|---|---|---|
| D1 | ArkUI + C++ NAPI，不用 Qt | UI/存储/mDNS 只能用 ArkTS；探测/扫描/解析下沉 C++ 满足"能 C++ 尽量 C++"；免去 Qt 运行库与平台插件维护成本 |
| D2 | TCP ping 替代 ICMP | 无公共 ping API；raw socket 无权限；TCP connect 计时对诊断足够 |
| D3 | 不做 netstat 式连接列表 | 纯 ArkTS 无 API 且沙箱读不到 /proc；不值得为此引入 native 库 |
| D4 | sweep 只扫默认网络子网 | 真机存在多网段（wlan0 + chba0），避免扫错网段 |
| D5 | 本地 SQLite（relationalStore） | 记录量小但需要筛选/合并，SQL 比 KV 合适；零权限 |
| D6 | 单 HAP、无 Worker | 全异步 IO，主线程充足；降低复杂度和包体 |
