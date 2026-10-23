# 木络 · MuNet

HarmonyOS NEXT 本地网络诊断工具箱：查看本机网络信息、TCP Ping、端口扫描、局域网设备发现与扫描记录。纯原生 ArkTS/ArkUI，探测与扫描核心用 C++ NAPI 实现，不依赖 Qt。

- 应用包名：`com.munet.app`（MuGe 系列）
- 显示名：木络；英文名：MuNet
- 当前版本：`0.4.0` / `1000004`
- 原名：NetTools

## 功能

- **本机网络**：网络卡、IP／前缀／网关／DNS／MTU、Wi-Fi 详情、原生 `getifaddrs` 网卡列表，地址可复制。
- **TCP Ping**：单次／持续探测、超时与统计、连接失败原因回显。
- **端口扫描**：常用端口预设、1–1024、自定义表达式、并发与超时配置、进度与停止；支持“扫描本机”查看占用端口。
- **局域网发现**：CIDR 主机并发探测、默认网段推导、mDNS 主机名归并、结果与设备档案。
- **扫描记录**：relationalStore 持久化、四类记录筛选、CSV／JSON 导出、再扫一次。
- **多端适配**：PC 侧栏 + 宽屏横排，窄窗底部标签；深色与最大字号适配。

## 当前状态

版本处于上架准备阶段：正式发布签名已完成并验签，代码与界面验收见[验证记录](docs/verification/README.md)。**尚未向应用市场提交审核**；隐私政策、主体／资质、后台应用身份与最终正式包质量验证仍需补齐，详见[上架资料](docs/release/2026-10-23-submission/README.md)和[发布准备](docs/RELEASE-READINESS.md)。

已知边界：

- 流量统计未接入：`GET_NETWORK_STATS` 属 `system_basic`，此前真机实测 denied。
- `/proc/net/tcp` 在应用沙箱不可读，本机监听端口改用 connect 扫描近似。
- 旧包 `com.muge.munet`、`com.mu.nettools` 的数据保留，暂不提供跨包迁移。

## 技术架构

ArkUI MVVM（View → ViewModel → Repository → Model）+ C++ NAPI 原生核心：

- UI 与状态：`@ComponentV2` / `@Observed`，页面只做渲染与事件转发。
- 原生核心 `libnettools.so`：非阻塞 connect + poll、线程池、TSFN 进度、代际取消、CIDR 展开。
- 持久化：`relationalStore`；导出：系统文件选择器。
- 分层规则、接口契约和命名规范见 [DESIGN.md](DESIGN.md)。

原生库和数据库沿用历史名 `libnettools.so`、`nettools.db`，避免破坏构建与已安装用户的数据；产品对外名称统一为木络／MuNet。

## 仓库结构

```
munet/
├── AppScope/                     # 应用级配置与资源
├── entry/src/main/
│   ├── ets/pages/                # 路由壳与页面装配
│   ├── ets/views/                # View 层（纯渲染）
│   ├── ets/viewmodel/            # ViewModel 层
│   ├── ets/repository/           # Repository 层（数据聚合、可 mock）
│   ├── ets/model/                # 纯类型
│   ├── ets/net/                  # 数据源（NetManager/WiFi/mDNS/NativeCore）
│   ├── ets/services/             # 剪贴板、导出等平台服务
│   ├── ets/store/                # relationalStore 持久化
│   └── cpp/                      # C++ 原生核心与 NAPI 类型
├── entry/src/ohosTest/           # hypium 测试
├── docs/                         # 文档入口见 docs/README.md
│   ├── design/                   # 冻结 UI 规范与图稿
│   ├── verification/             # 按阶段归档的验证证据
│   ├── release/                  # 按日期归档的发布资料
│   └── brand/                    # 品牌源图与提示词
├── scripts/check_release.py      # Release 产物检查
└── sign_tools/                   # 本地签名材料（不入库）
```

## 构建 / 签名 / 部署

```bash
# 0) 依赖（首次或改过 oh-package.json5）
export PATH="/c/Program Files/Huawei/DevEco Studio/tools/node:/c/Program Files/Huawei/DevEco Studio/tools/ohpm/bin:$PATH"
ohpm install --all

# 1) 构建（产物异常时再清理 entry/build 与 .hvigor）
export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
./hvigorw assembleHap --mode module -p product=default -p buildMode=debug

# 2) 签名（每个设备 UDID 单独签一次；脚本与材料在仓库外）
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

## 文档

- [文档索引](docs/README.md)
- [整体设计](DESIGN.md)
- [验证记录](docs/verification/README.md)
- [发布与上架资料](docs/release/README.md)
- [权限清单](docs/PERMISSIONS.md)

## 构建注意事项

1. **增量打包可能漏 `ets/modules.abc`**：首次 CompileArkTS 失败后，增量 HAP 可能缺字节码，真机表现为 `JsRuntime: run script failed` / `null jsAbilityObj` / 卡启动图。先核对 HAP 内 `ets/modules.abc` 非空，再清理构建目录重建；Release 用 `scripts/check_release.py` 复核。
2. **OHM 类型依赖名必须一致**：`entry/oh-package.json5` 中必须是 `"libnettools.so": "file:./src/main/cpp/types/libnettools"`，key 要与类型包 `name` 相同，否则 ArkTS 导入退化为 any 并报 `arkts-no-any-unknown`。
3. **签名与 UDID 绑定**：debug profile 的 `device-ids` 由签名脚本按参数生成，换设备需重签；UDID 用 `hdc shell bm get --udid` 获取。
4. **验证纪律**：UI 结论以截图／OCR 为准，不只看日志；网络结论必须在真机真实网络环境下验证。
