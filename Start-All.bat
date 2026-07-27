@echo off
chcp 65001 >nul
cd /d "%~dp0"
title meowsic Start-All
echo.
echo  meowsic — start server + browser + Windows app (if built)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mobile\Start-All.ps1"
if errorlevel 1 pause
