param(
  [Parameter(Mandatory = $false)]
  [string]$DeviceId = "",
  [Parameter(Mandatory = $false)]
  [ValidateSet("prod", "dev")]
  [string]$Flavor = "prod"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path
$ApkName = "app-$Flavor-debug.apk"
$ApkPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\$ApkName"
$PackageName = if ($Flavor -eq "dev") { "com.friend.ios.dev" } else { "com.friend.ios" }

Write-Host "== Build Flutter APK (debug, $Flavor flavor) ==" -ForegroundColor Cyan
Push-Location $ProjectRoot
flutter build apk --debug --flavor $Flavor
Pop-Location

if (-not (Test-Path $ApkPath)) {
  throw "APK not found at $ApkPath"
}

Write-Host "== Select device ==" -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  $devices = (& adb devices) | Select-String "\tdevice$"
  if ($devices.Count -eq 0) { throw "No adb device connected" }
  if ($devices.Count -gt 1) { throw "Multiple devices connected. Please pass -DeviceId <id>." }
  $DeviceId = ($devices[0].Line -split "\t")[0]
}
Write-Host "Using device: $DeviceId"

Write-Host "== ADB reverse (local backend) ==" -ForegroundColor Cyan
& adb -s $DeviceId reverse tcp:8000 tcp:8000 | Out-Host

Write-Host "== Install APK ==" -ForegroundColor Cyan
& adb -s $DeviceId install -r $ApkPath | Out-Host

Write-Host "== Launch app ==" -ForegroundColor Cyan
& adb -s $DeviceId shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Host

Write-Host "== Logcat (TEN VAD) ==" -ForegroundColor Cyan
& adb -s $DeviceId logcat -d -s "TEN_VAD:*" "flutter:*" "AndroidRuntime:E" | Select-Object -Last 200

