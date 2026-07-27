# meowsic: start server (../server) + open web + optional Windows app
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot   # meowsic-github/
if (-not (Test-Path (Join-Path $Root "server"))) {
  $Root = Split-Path -Parent $PSScriptRoot
}
$HubDir = Join-Path $Root "server"
$HubUrl = "http://127.0.0.1:8787"
$HubPy = Join-Path $HubDir ".venv\Scripts\python.exe"
$AppExeDebug = Join-Path $PSScriptRoot "build\windows\x64\runner\Debug\music_hub_app.exe"
$AppExeRelease = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\music_hub_app.exe"
$LogFile = Join-Path $PSScriptRoot "start-all.log"

function Log([string]$msg) {
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
  Write-Host $line
  Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

Set-Content -Path $LogFile -Value "" -Encoding UTF8
Log "==== meowsic start all ===="
Log "Server dir: $HubDir"

function Test-HubUp {
  try {
    $r = Invoke-WebRequest -Uri "$HubUrl/api/status" -UseBasicParsing -TimeoutSec 2
    return ($r.StatusCode -eq 200)
  } catch {
    return $false
  }
}

# 1) Server
if (Test-HubUp) {
  Log "Server already running: $HubUrl"
} else {
  Log "Server not running, starting..."
  if (-not (Test-Path $HubPy)) {
    Log "Creating venv + installing deps..."
    Push-Location $HubDir
    try {
      python -m venv .venv
      & ".\.venv\Scripts\python.exe" -m pip install -r requirements.txt
    } finally {
      Pop-Location
    }
  }
  if (-not (Test-Path $HubPy)) {
    Log "ERROR: still missing $HubPy — is Python installed?"
    Read-Host "Press Enter to exit"
    exit 1
  }

  $cmd = @"
Write-Host 'meowsic SERVER - keep this window OPEN'
Write-Host 'URL: http://127.0.0.1:8787'
Write-Host 'Close this window = stop music service'
Write-Host ''
Set-Location -LiteralPath '$HubDir'
& '$HubPy' -m uvicorn app.main:app --host 0.0.0.0 --port 8787
Write-Host ''
Write-Host 'Server stopped.'
Read-Host 'Press Enter to close'
"@
  Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoExit",
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command", $cmd
  ) -WindowStyle Normal

  Log "Server window opened, waiting..."
  $ok = $false
  for ($i = 1; $i -le 40; $i++) {
    Start-Sleep -Seconds 1
    if (Test-HubUp) {
      $ok = $true
      Log "Server ready (${i}s)"
      break
    }
    Write-Host -NoNewline "."
  }
  Write-Host ""
  if (-not $ok) {
    Log "WARN: server not responding yet — check the server window"
  }
}

# 2) Open web
try {
  Start-Process $HubUrl
  Log "Opened browser $HubUrl"
} catch {
  Log "Could not open browser: $_"
}

# 3) Windows Flutter app if built
$app = $null
if (Test-Path $AppExeRelease) { $app = $AppExeRelease }
elseif (Test-Path $AppExeDebug) { $app = $AppExeDebug }

if ($app) {
  Log "Starting Windows app: $app"
  Start-Process -FilePath $app
} else {
  Log "No Windows app build found. Optional:"
  Log "  cd mobile; flutter run -d windows"
}

Log "Done. Keep server window open while listening."
Write-Host ""
Write-Host "Phone: same Wi-Fi, open http://<PC-LAN-IP>:8787 or install APK and scan QR"
Write-Host ""
