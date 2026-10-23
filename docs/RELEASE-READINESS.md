# 木络0.4.0发布准备

最新产品化检查：**可以准备资料，暂不能送审**。输入纠错及CSV文本防护已修复，三端单元测试各16/16；仍待正式签名、隐私配置、资质与正式包质量验证。[本轮报告](release/2026-10-23/README.md)／[需要开发者办理的清单](release/2026-10-23/USER-ACTIONS.md)。

2026-10-23 更新。当前准备的是可复核的代码提交与Release候选产物，未创建市场发布单、上传或送审。保留包名`com.mu.nettools`、版本`0.4.0`／`1000004`，正式送审前仍需与AGC已有版本核对，不假设此前已经发布。手机／平板模拟器验收见[阶段9](ui-verification/phase9/README.md)，最新PC实机验收见[阶段10](ui-verification/phase10/README.md)，权限申请见[清单](PERMISSIONS.md)。

## 候选产物

- `artifacts/release/0.4.0/munet-0.4.0-20261023-store-prep-unsigned.app`：完成输入纠错及CSV文本防护后的最新未签名Release应用包。
- `artifacts/release/0.4.0/munet-0.4.0-20261023-store-prep-unsigned.hap`：最新未签名Release主模块；此前PC及触屏候选保留，不覆盖历史产物。
- PC本地签名的Release HAP仅用于已连接设备验收，使用设备绑定调试签名，不能当作正式市场签名。
- 二进制放在忽略目录，不把签名材料、设备绑定配置或构建产物提交Git；最新检查结果及SHA-256见[产物清单](release/2026-10-23/release-manifest.json)。

Release构建命令（DevEco Studio运行环境）：

```powershell
$env:DEVECO_SDK_HOME='C:\Program Files\Huawei\DevEco Studio\sdk'
$env:JAVA_HOME='C:\Program Files\Huawei\DevEco Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;C:\Program Files\Huawei\DevEco Studio\tools\node;$env:Path"
& 'C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe' 'C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js' assembleApp --mode project -p product=default -p buildMode=release
python scripts/check_release.py --hap entry/build/default/outputs/default/entry-default-unsigned.hap --app build/outputs/default/nettools-default-unsigned.app --output artifacts/release-manifest.json
```

检查脚本验证：`debug=false`、Release构建模式、包名与版本、entry随应用安装、仅三项声明权限、非空ArkTS字节码、arm64-v8a／x86_64的真实ELF架构、无测试资源／测试模块，以及APP内HAP与独立HAP运行文件一致。打包器可重排`pack.info`格式，但内容必须相同。已确认Debug产物会被拒绝。清单中的源码SHA可用于核对候选包对应的源文件。

主模块`deliveryWithInstall`修正为true，使其随应用安装；含义参考[OpenHarmony官方模块配置说明](https://raw.githubusercontent.com/openharmony/docs/master/en/application-dev/quick-start/module-configuration-file.md)。签名配置仍由本地正式材料提供，不将私钥写进工程。

## 产品行为与数据

1. 网络页面展示系统网卡及Wi-Fi信息，接口有地址不表示互联网可达。
2. Ping为TCP连通性探测；关闭端口／防火墙拦截不表示主机离线。服务名是常见端口用途，不是服务指纹。
3. 扫描记录及发现过的设备档案保存在本机；导出CSV／JSON仅在用户选择系统保存位置后写入文件。清空同时删除两类记录，确认文案明确范围。
4. 声明权限只有INTERNET、GET_NETWORK_INFO、GET_WIFI_INFO；没有账户、云同步或流量统计功能。
5. Release隐藏诊断入口，Debug无界面探测参数在Release不执行。关于页按用户要求保留基础介绍，移除版本、应用标识与核心版本；隐私段落未恢复，没有补造政策URL。首页侧栏只显示木络。

这份数据说明供准备资料核对，不能替代开发者最终确认的隐私政策或市场申报内容。

## 提交市场前仍需完成

- 关联正确AGC应用，提供正式发布证书／签名配置，对最终正式签名包再次检查与安装验证。
- 核对AGC已有版本号、正式应用介绍、适用设备和上传页要求的图标及真实截图；设计稿不能充当宣传截图。
- 由开发者确认对外数据处理说明、政策内容与联系方式。应用内隐私段落按用户要求删除，不在本轮重新加入占位文字。
- 手机和平板末版模拟器验收已完成，见阶段9；真实Wi-Fi／局域网兼容性和完整读屏语音听测仍需实机／人工，不将模拟器当成真机证据。
- 构建存在既有SDK弃用／异常处理提示，保留完整日志；无编译错误不等同于已满足全部市场检查。

最新PC逐页对照、修复和设备证据见[阶段10报告](ui-verification/phase10/README.md)，手机／平板见[阶段9报告](ui-verification/phase9/README.md)；阶段8保留为当时的历史候选。
