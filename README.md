# 木络 · MuNet

当前包名 `com.munet.app`（MuGe 系列），显示名“木络”。最新检查见[更名与重新安装验收](docs/release/2026-10-23-munet-app/README.md)；此前[包名变更记录](docs/release/2026-10-23-bundle-layout/README.md)保留。旧包 `com.muge.munet`、`com.mu.nettools` 的数据保留，暂未提供跨包迁移。

新包名上架资料、权限范围及开发者回填清单统一见[上架资料入口](docs/release/2026-10-23-submission/README.md)。[正式发布签名已完成并验证](docs/release/2026-10-23-formal-signing/README.md)，仍待隐私、资质及正式包质量验证后送审。

原项目名NetTools。应用图标与名称已切换为木络；设计与改造进度见[品牌资源](docs/brand/README.md)和[UI改造计划](docs/UI-MIGRATION.md)。

HarmonyOS 本地网络诊断工具箱：本机网络信息 / TCP Ping / 端口扫描 / 局域网
设备发现 / 扫描记录。整体设计见 [DESIGN.md](DESIGN.md)。

**架构**：ArkUI MVVM（View / ViewModel / Repository / Model）+ C++ NAPI
原生核心（`libnettools.so`，探测/扫描/解析）。
分层与命名规范见 DESIGN.md §4.1 / §4.2.1。不用 Qt。

## 当前状态（v0.4.0）

上架准备：输入纠错及CSV文本防护补丁已验证，三端单元测试各16/16；当前待正式发布签名、隐私／主体／资质资料及正式包质量检查。见[产品化检查](docs/release/2026-10-23/README.md)与[开发者资料清单](docs/release/2026-10-23/USER-ACTIONS.md)。

- ✅ DevEco 工程 + C++ 交叉编译 + NAPI 打通
- ✅ **M1 本机网络页**：NetManager 网络卡（IP/前缀/网关/DNS/MTU/bearer）+
  WiFi 详情 + 原生 `getifaddrs` 全部网卡 + 点击复制（真机与 `ifconfig`
  逐项核对一致）
- ✅ **M2 Ping + 端口扫描**：原生 `scanPorts`（线程池并发 + TSFN 进度 +
  代际取消）、`parsePortExpr`；Ping 智能回退/持续模式/统计，端口扫描
  预设/1-1024/自定义/并发超时/停止。真机验证：
  - Ping 开放端口 `sent=3 recv=3 loss=0% [0ms,2ms,1ms]`；关闭端口
    `loss=100% [refused,refused]`
  - 公网扫描 `223.5.5.5 → 53/80/443 开放，RTT 32–34ms`
- ✅ **M3 局域网 + 记录**：原生 `sweepCidr`（CIDR 主机并发 + 进度/取消）、
  默认网段自动推导、mDNS 主机名归并（best-effort）、relationalStore
  历史记录与设备档案、四类记录筛选与清空。真机验证：
  - `127.0.0.1/32` → `online=1 [127.0.0.1[28400]]`，8ms
  - `100.70.104.0/28` → 14 主机全探测，6.0s（6 端口 × 1s 超时）
  - Ping 记录写入并读回：`kind=ping target=127.0.0.1 status=done`
  - 局域网页自动推导 `100.70.104.0/23`（510 台）；记录页正常展示
- ✅ **M4 打磨**：历史 CSV/JSON 导出（系统文件选择器，实测写入 237 bytes）、
  记录「再扫一次」（跨页回填目标）、设备档案页签（`discovered_host`：
  IP/端口/最近发现）、**端口扫描「扫描本机」模式**（127.0.0.1/::1/本机 IPv4
  逐地址探测去重，实测找出 4 个占用端口）、关于页、回车启动、窄屏底部标签
  导航、x86_64 ABI。
- ⏳ 流量统计：此前 `GET_NETWORK_STATS` 真机实测 `denied`（system_basic），
  当前版本未接入；拟扩展时先核对AGC受限权限申请资格，见[权限清单](docs/PERMISSIONS.md)。
- ❌ `/proc/net/tcp` 本机监听表：应用沙箱 `denied`，改走 connect 扫描近似。
- ✅ **单元测试**：ohosTest（hypium）覆盖 `Subnet` 与 `HistoryExportFormat`，
  原有记录为6/6；当前完整桌面专项包含14项单元测试与1项综合测试，结果和边界见下方最新验收。

## 目录

最新UI对照与验证见[阶段8报告](docs/ui-verification/phase8/README.md)，发布候选产物和剩余条件见[发布准备](docs/RELEASE-READINESS.md)。PC采用左侧导航、宽屏横排参数；窄窗与大字号回退单列。关于页隐私说明已按用户要求删除，诊断入口仅Debug可见。文档和候选产物不表示已向应用市场送审。

2026-10-23末版更新：手机／平板模拟器完整专项与平板窄窗专项均15/15通过；深色、最大字体、716vp分屏及全屏恢复已复核。手机操作面板改为至少56vp的原生按钮；首页侧栏只显示木络，关于改为基础介绍，不显示版本与标识。见[阶段9归档](docs/ui-verification/phase9/README.md)及[权限申请清单](docs/PERMISSIONS.md)。旧能力矩阵的受限权限结论为历史实测，不代表API 26所有接口均不可申请。

2026-10-23 PC补验：MateBook当前Release六档真实窗口、七页设计对照、短窗、运行中缩放和键鼠综合专项15/15通过；深色与最大字体专项各15/15通过。修复PC窄窗记录页误用手机Sheet，改为原生锚定菜单；补查复制粘贴、方向键选择、非法端口、重测回填、导出取消及清空取消，保留用户数据。见[阶段10归档](docs/ui-verification/phase10/README.md)。

```
nettools/
├── AppScope/                     # bundle: com.munet.app
├── entry/src/main/
│   ├── ets/pages/Index.ets       # 路由壳（导航 + View 装配）
│   ├── ets/views/                # View 层（纯渲染）
│   ├── ets/viewmodel/            # ViewModel 层（@Observed）
│   ├── ets/repository/           # Repository 层（数据聚合 / 可 mock）
│   ├── ets/model/                # 纯类型（NetworkInfo/ScanInfo/HistoryInfo）
│   ├── ets/net/                  # 数据源（NetManager/WiFi/Mdns/NativeCore）
│   ├── ets/services/             # 平台服务（Clipboard/HistoryExporter）
│   ├── ets/store/                # 持久化仓储（M3）
│   ├── cpp/                      # ★ C++ 原生核心（probeTcp/listInterfaces）
│   └── module.json5              # INTERNET / GET_NETWORK_INFO / GET_WIFI_INFO
├── build-profile.json5           # compatible 6.0.2(22) / target 26.0.0
└── hvigorw(.bat)                 # 转发到 DevEco 自带 hvigor
```

## 构建 / 签名 / 部署

```bash
# 0) 依赖（首次或改过 oh-package.json5）
export PATH="/c/Program Files/Huawei/DevEco Studio/tools/node:/c/Program Files/Huawei/DevEco Studio/tools/ohpm/bin:$PATH"
ohpm install --all

# 1) 构建（显式指定模式，仅在产物异常时清理）
export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
./hvigorw assembleHap --mode module -p product=default -p buildMode=debug

# 2) 签名（每个设备 UDID 单独签一次；脚本与材料在同级 thirty 工作区，不入本仓库）
bash ../thirty/tools/sign-local.sh entry/build/default/outputs/default/entry-default-unsigned.hap \
    entry-default-signed.hap <UDID> com.munet.app

# 3) 安装 + 启动
MSYS_NO_PATHCONV=1 hdc -t <UDID> install -r entry-default-signed.hap
MSYS_NO_PATHCONV=1 hdc -t <UDID> shell "aa start -a EntryAbility -b com.munet.app -m entry"

# 4) 单元测试（ohosTest / hypium）
./hvigorw --mode module -p module=entry@ohosTest -p product=default assembleHap
bash ../thirty/tools/sign-local.sh entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap \
    entry-ohosTest-signed.hap <UDID> com.munet.app
MSYS_NO_PATHCONV=1 hdc -t <UDID> install -r entry-ohosTest-signed.hap
MSYS_NO_PATHCONV=1 hdc -t <UDID> shell \
    "aa test -b com.munet.app -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 60000"
```

## 注意事项（踩过的坑）

1. **增量打包可能漏掉 `ets/modules.abc`**：首次构建若 CompileArkTS 失败过，
   之后增量打包出的 HAP 可能没有字节码，真机表现为 `JsRuntime: run script
   failed` / `null jsAbilityObj` / 永久卡启动图。先核对HAP中存在非空的
   `ets/modules.abc`，确认路径后再清理本工程构建目录并重建。Release可使用
   `scripts/check_release.py`核对，不能用旧包的成功构建代替当前源码验证。
2. **OHM 类型依赖名必须一致**：`entry/oh-package.json5` 里必须是
   `"libnettools.so": "file:./src/main/cpp/types/libnettools"`（key 与类型包
   `name` 一致）；写成 `@types/libnettools.so` 会导致 ArkTS 侧导入退化为
   any，报 `arkts-no-any-unknown`。
3. **签名与 UDID 绑定**：debug profile 的 `device-ids` 由签名脚本按参数
   生成，换设备要重新签。设备 UDID 用 `hdc shell bm get --udid` 获取。
4. **验证纪律**：UI 结论以截图/OCR 为准，不只看日志；网络结论必须在真机
   真实网络环境下验证。
