# 木络 1.0.0 发布准备

包名 `com.munet.app`（由 `com.muge.munet` 更换，最初为 `com.mu.nettools`），版本 `1.0.0` / `1000000`，显示名木络，英文名 MuNet。

**正式发布签名已完成并验签；尚未提交应用市场审核。** 仍需核对后台应用身份与版本、隐私政策正文与主体／联系信息、资质，并对正式签名包做最终质量验证。

## 发布包

发布交付目录为项目根目录 `dist/`，不进入 Git：

- `dist/MuNet-1.0.0-release-signed.app`：正式发布签名 APP。
- `dist/MuNet-1.0.0-release-signed.hap`：正式签名主模块，与 APP 分别通过 SDK 验签。
- `dist/release-manifest.json`：产物清单与 SHA。

默认打包命令：

```powershell
python scripts/package_release.py
```

需先在本机配置正式签名；使用仓库外的签名构建快照时传入 `--project <快照路径>`。脚本执行正式构建与 SDK 验签后，将 APP、HAP 和清单导出到 `dist/`；对已构建的快照可加 `--skip-build`，仍会验签。

签名材料、Profile、密钥库和本机签名配置放在忽略目录 `sign_tools/` 或仓库外，不提交 Git。

## Release 构建与检查

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:JAVA_HOME='C:\Program Files\Huawei\DevEco Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;C:\Program Files\Huawei\DevEco Studio\tools\node;$env:Path"
& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' 'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js' assembleApp --mode project -p product=default -p buildMode=release
python scripts/check_release.py --hap entry/build/default/outputs/default/entry-default-unsigned.hap --app build/outputs/default/munet-default-unsigned.app --output artifacts/release-manifest.json
```

APP 产物名取自工程目录名；本地目录不叫 `munet` 时，按 `build/outputs/default/` 下实际文件名替换。

`scripts/check_release.py` 验证：`debug=false`、Release 构建模式、包名与版本、entry 随应用安装、仅三项声明权限、非空 ArkTS 字节码、arm64-v8a／x86_64 的真实 ELF 架构、无测试资源／测试模块，以及 APP 内 HAP 与独立 HAP 运行文件一致。Debug 产物会被拒绝。

## 产品行为与数据

1. 网络页面展示系统网卡及 Wi-Fi 信息；接口有地址不表示互联网可达。
2. Ping 为 TCP 连通性探测；关闭端口／防火墙拦截不表示主机离线。服务名是常见端口用途，不是服务指纹。
3. 扫描记录及发现过的设备档案保存在本机；导出 CSV／JSON 仅在用户选择系统保存位置后写入文件。清空同时删除两类记录，确认文案明确范围。
4. 声明权限只有 INTERNET、GET_NETWORK_INFO、GET_WIFI_INFO；没有账户、云同步或流量统计功能。
5. Release 隐藏诊断入口，Debug 无界面探测参数在 Release 不执行。关于页保留基础介绍，移除版本、应用标识与核心版本；隐私声明使用 AGC 托管链接并写入包内，政策正文与联系方式仍需确认。首页侧栏只显示木络。

本页是发布核对清单，不能替代开发者最终确认的隐私政策或市场申报内容。

## 提交市场前仍需完成

- 在 AGC 核对应用身份、包名、版本号、适用设备与上传页要求。
- 确认隐私政策正文、主体／联系信息与资质材料；应用内不加入占位文案。
- 对正式签名包补做平台质量与兼容性验证，包括真实 Wi-Fi／局域网场景、API 22 机型和读屏。
- 核对商店介绍、图标与真实截图；设计稿不能充当宣传截图。
- 保留构建日志；无编译错误不等同于已满足全部市场检查。
