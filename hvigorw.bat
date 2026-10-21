@echo off
setlocal
rem TASK-M0-01 工程 wrapper：转发到 DevEco Studio 官方 hvigor wrapper。
rem 官方 hvigorw.js 依赖自身位置推导 hvigor 主包路径，必须在其安装目录运行，
rem 因此这里不复制官方脚本，只做定位与转发。

set "DEVECO_HVIGOR_WRAPPER="
if defined DEVECO_STUDIO_PATH (
  if exist "%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.js" set "DEVECO_HVIGOR_WRAPPER=%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.js"
)
if not defined DEVECO_HVIGOR_WRAPPER (
  if exist "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" set "DEVECO_HVIGOR_WRAPPER=C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js"
)
if not defined DEVECO_HVIGOR_WRAPPER (
  echo ERROR: DevEco Studio hvigor wrapper not found. 1>&2
  echo Set DEVECO_STUDIO_PATH to the DevEco Studio install dir, or install to the default location. 1>&2
  exit /b 1
)

if defined NODE_HOME (
  "%NODE_HOME%\node.exe" "%DEVECO_HVIGOR_WRAPPER%" %*
) else (
  node "%DEVECO_HVIGOR_WRAPPER%" %*
)
exit /b %ERRORLEVEL%