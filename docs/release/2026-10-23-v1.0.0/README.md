# 木络 1.0.0 首发打包记录

2026-10-23。包名`com.munet.app`，版本`1.0.0`，按用户指定首发versionCode为`1000000`。

## 本次变更

- 更新项目版本，纳入用户本地新增的应用市场隐私声明托管标记、正式隐私声明链接及`avoid_cutout`元数据。
- 继续使用MuMark发布密钥／证书和木络的app_gallery发布Profile。在仓库外构建快照中使用本机加密签名配置，未提交密钥、口令或Profile。
- 通过DevEco Hvigor正式Release构建；APP和独立HAP分别通过SDK验签，提取Profile与本机发布Profile的SHA一致。
- 检查两个容器内的包名、版本、Release模式、三项普通权限、隐私元数据、双架构原生库、无测试资源；64个构建输入文件与当前项目一致。

## 上传文件

上传`dist/MuNet-1.0.0-release-signed.app`。独立HAP留作模块核验；[签名及文件SHA清单](signing-manifest.json)记录正式输出。

包内隐私声明链接：

https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=2067524291418708672

本轮验证链接已写入包内，未核验托管页面正文、运营主体和联系信息，也未替代隐私检测。设备运行验收仍为此前0.4.0基线，本次未重跑三端设备测试。签名通过不代表已完成市场最终质量验证或已提交审核；剩余资料见[开发者清单](../2026-10-23-submission/OWNER-CHECKLIST.md)。

APP内HAP与独立HAP存在SDK正常容器差异：独立HAP多`.pages.info`，`pack.info`分发元数据不同，其余共有文件一致。
