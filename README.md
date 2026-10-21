# NetTools（网络工具箱）

HarmonyOS 本地网络诊断工具箱：本机网络信息 / TCP Ping / 端口扫描 / 局域网
设备发现 / 扫描记录。整体设计见 [DESIGN.md](DESIGN.md)。

**架构**：ArkUI MVVM（View / ViewModel / Repository / Model）+ C++ NAPI
原生核心（`libnettools.so`，探测/扫描/解析）。
分层与命名规范见 DESIGN.md §4.1 / §4.2.1。不用 Qt。

## 当前状态（v0.4.0）

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
- ❌ 流量统计：`GET_NETWORK_STATS` 真机实测 `denied`（system_basic），
  普通应用不可用，已放弃。
- ❌ `/proc/net/tcp` 本机监听表：应用沙箱 `denied`，改走 connect 扫描近似。

## 目录

```
nettools/
├── AppScope/                     # bundle: com.mu.nettools
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

# 1) 构建（首次失败过或改过 ets 后必须先清理，见下方注意事项）
export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
./hvigorw assembleHap --mode module -p product=default debuggable

# 2) 签名（每个设备 UDID 单独签一次；工具在仓库根的 tools/ 下）
cd ..
bash tools/sign-local.sh nettools/entry/build/default/outputs/default/entry-default-unsigned.hap \
    nettools/entry-default-signed.hap <UDID> com.mu.nettools

# 3) 安装 + 启动
MSYS_NO_PATHCONV=1 hdc -t <UDID> install -r nettools/entry-default-signed.hap
MSYS_NO_PATHCONV=1 hdc -t <UDID> shell "aa start -a EntryAbility -b com.mu.nettools -m entry"
```

## 注意事项（踩过的坑）

1. **增量打包可能漏掉 `ets/modules.abc`**：首次构建若 CompileArkTS 失败过，
   之后增量打包出的 HAP 可能没有字节码，真机表现为 `JsRuntime: run script
   failed` / `null jsAbilityObj` / 永久卡启动图。**先 `rm -rf entry/build
   .hvigor` 再构建**，并用 `unzip -l <hap> | grep modules.abc` 确认。
2. **OHM 类型依赖名必须一致**：`entry/oh-package.json5` 里必须是
   `"libnettools.so": "file:./src/main/cpp/types/libnettools"`（key 与类型包
   `name` 一致）；写成 `@types/libnettools.so` 会导致 ArkTS 侧导入退化为
   any，报 `arkts-no-any-unknown`。
3. **签名与 UDID 绑定**：debug profile 的 `device-ids` 由签名脚本按参数
   生成，换设备要重新签。设备 UDID 用 `hdc shell bm get --udid` 获取。
4. **验证纪律**：UI 结论以截图/OCR 为准，不只看日志；网络结论必须在真机
   真实网络环境下验证。
