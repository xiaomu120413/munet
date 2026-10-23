# 木络正式发布签名核验

2026-10-23。应用com.munet.app／木络／0.4.0／1000004，源码基线b45b345。按用户指示复用MuMark的正式证书及原密钥配置，为木络使用新生成的发布Profile；未上传或提交应用市场。

## 已完成

- 将本项目sign_tools中的Mumark.cer改名为MuNetRelease.cer，文件内容及证书身份不变。整个sign_tools目录已加入Git忽略，不提交证书、Profile、密钥、CSR或本机加密材料。
- SDK验证MuNetRelease.p7b通过：type=release、app-distribution-type=app_gallery，包名com.munet.app。证书链中实际签名证书与Profile分发证书公钥匹配，有效期核对通过。
- 找到MuMark已使用的本机正式签名配置，在仓库外隔离源码快照中复用。口令沿用本机加密配置，没有写入Git工作区；未改动MuMark的文件或配置。
- 通过DevEco SDK标准assembleApp的Release流程构建，正式APP和独立HAP分别通过hap-sign-tool verify-app；提取的Profile与用户提供文件SHA一致。
- 核对包名、版本、debug=false、Release模式和三项普通权限；运行源码与此前验收版本一致（文本仅允许Git换行规范化）。私有快照仅替换签名配置，未改变业务代码。

标准SDK输出中APP内HAP与独立签名HAP不是字节相同：独立HAP多.pages.info，pack.info分发信息不同。其他共有文件逐字节一致，APP与HAP的签名均独立校验通过；不把合法打包差异当成运行代码不一致。

## 新生成材料的检查结论

用户随后生成了MuNet.p12和MuNet.csr。新CSR的公钥与现有MuNetRelease.cer不匹配，也不同于原MuMark CSR，因此本次签名没有使用新MuNet密钥库。

按用户要求，已将未使用的`sign_tools/MuNet.p12`、`sign_tools/MuNet.csr`及其对应的`sign_tools/material`目录移入回收站。当前项目签名目录仅保留`MuNetRelease.cer`和`MuNetRelease.p7b`；继续使用原MuMark密钥库及本机加密签名配置，已签名发布包不受影响。上述本机材料均被Git忽略，本次仅提交清理记录，不提交密钥或口令。

如继续复用原MuMark证书，沿用原密钥配置即可；若要切换到新MuNet密钥，需先用新CSR在开发者中心申请对应证书，并重新生成com.munet.app的发布Profile，再重新签名。仅重命名或生成.p12／.csr不能使旧证书与新密钥匹配。

## 输出

- artifacts/release/0.4.0/MuNet-0.4.0-release-signed.app：正式发布签名APP。
- artifacts/release/0.4.0/MuNet-0.4.0-release-signed.hap：正式发布签名主模块。
- [签名核验与SHA清单](signing-manifest.json)。原始Profile验证内容、签名配置和诊断日志仅保存在忽略目录或仓库外，不随文档提交。

这是正式签名通过，不等同于完成上架审核或最终质量测试。隐私、备案／资质、后台版本核对和正式包质量专项仍见[开发者清单](../2026-10-23-submission/OWNER-CHECKLIST.md)。未用应用市场发布Profile替代调试Profile冒充本地安装验收。
