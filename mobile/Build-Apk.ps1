# Build meowsic APK (release) for local install.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

# Optional local paths (edit if your machine differs)
if (Test-Path "D:\flutter\bin") {
  $env:Path = "D:\flutter\bin;" + $env:Path
}
if (Test-Path "D:\Android studio\jbr") {
  $env:JAVA_HOME = "D:\Android studio\jbr"
  $env:Path = "$env:JAVA_HOME\bin;" + $env:Path
}
if (Test-Path "D:\AndroidSDK") {
  $env:ANDROID_HOME = "D:\AndroidSDK"
  $env:ANDROID_SDK_ROOT = "D:\AndroidSDK"
  $env:Path = "$env:ANDROID_HOME\platform-tools;" + $env:Path
}

Write-Host "[meowsic] flutter pub get..."
flutter pub get
Write-Host "[meowsic] flutter build apk --release..."
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

$src = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $src)) { throw "APK not found: $src" }

$size = [math]::Round((Get-Item $src).Length / 1MB, 1)
Write-Host ""
Write-Host "OK: $src  ($size MB)"
Write-Host "Copy the APK to your phone and install."
Write-Host ""
