@echo off
chcp 65001 >nul
cd /d "%~dp0"
title meowsic Start
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-All.ps1"
if errorlevel 1 pause
