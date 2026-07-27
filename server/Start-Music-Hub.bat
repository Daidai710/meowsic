@echo off
chcp 65001 >nul
cd /d "%~dp0"
title meowsic server

if not exist ".venv\Scripts\python.exe" (
  echo [meowsic] Creating venv...
  python -m venv .venv
  if errorlevel 1 (
    echo Failed to create venv. Install Python 3.10+ and add it to PATH.
    pause
    exit /b 1
  )
  call ".venv\Scripts\activate.bat"
  pip install -r requirements.txt
) else (
  call ".venv\Scripts\activate.bat"
)

REM Optional FFmpeg for rare formats:
REM set "MUSIC_HUB_FFMPEG_PATH=C:\path\to\ffmpeg.exe"

echo.
echo  meowsic server
echo  Web player:  http://127.0.0.1:8787
echo  Phone: same Wi-Fi, use PC LAN IP, port 8787
if not "%MUSIC_HUB_FFMPEG_PATH%"=="" echo  FFmpeg:  %MUSIC_HUB_FFMPEG_PATH%
echo  Keep this window open while listening.
echo.

python -m uvicorn app.main:app --host 0.0.0.0 --port 8787
pause
