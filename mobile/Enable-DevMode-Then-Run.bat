@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "PATH=D:\flutter\bin;%PATH%"

echo ============================================================
echo  Music Hub App - Windows
echo ============================================================
echo.
echo  Flutter 在 Windows 上需要「开发人员模式」才能创建插件符号链接。
echo  即将打开系统设置，请打开：
echo    设置 → 隐私和安全性 → 面向开发人员 → 开发人员模式 = 开
echo.
echo  打开后回到本窗口按任意键继续...
echo ============================================================
start ms-settings:developers
pause

echo.
echo 正在检查...
flutter doctor -v 2>nul | findstr /i "windows chrome"
echo.
echo 启动 App（连接地址可用 127.0.0.1:8787，请先启动 music-hub 服务）
echo.
flutter run -d windows
if errorlevel 1 (
  echo.
  echo 若仍报 symlink / Developer Mode：
  echo   1. 确认开发人员模式已打开
  echo   2. 关闭本窗口重新运行本脚本
  echo   3. 或以管理员身份运行终端后再试
  echo.
  pause
)
