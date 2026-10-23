# 本地打包与目录约定

在项目根目录执行`python scripts/package_release.py`。需要Git、Python及DevEco Studio；SDK及Node使用DevEco安装目录，支持`DEVECO_STUDIO_HOME`或`DEVECO_STUDIO_PATH`覆盖默认安装位置。

## 签名和输出

签名材料集中在Git忽略目录`sign_tools/`：`MuNetRelease.p12`、`MuNetRelease.cer`、`MuNetRelease.p7b`、`signing-config.json`和配套`material/`。配置中的`storeFile`、`certpath`和`profile`使用相对于该目录的文件名；脚本在构建时解析为当前项目下的路径，不绑定开发者桌面位置。

每次打包在`sign_tools/`内创建新的构建副本，使用当前源码，完成或失败后自动清理。`oh_modules`通过目录联接共享，清理副本只移除联接，不删除真实依赖。已删除的源码不会从旧副本带入下一次构建。

正式APP、HAP及`release-manifest.json`输出到`dist/`；SDK验签日志及提取的证书／Profile保存在`sign_tools/verification/`。这些目录不进入Git。默认打包无需仓库外的签名副本或其他项目的脚本。

显式指定`--project <路径>`仍可打包其他已配置签名的副本；`--skip-build`仅可与此参数一起使用。默认流程始终从当前源码重新构建。

## 开发设备

设备调试包和ohosTest包使用本项目DevEco调试签名，按连接设备配置Profile。正式app_gallery发布Profile不用于替代设备调试Profile。
