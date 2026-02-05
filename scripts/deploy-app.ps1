# Omi 快速部署脚本
# 用法: .\scripts\deploy-app.ps1 [-Release] [-SkipBuild] [-NoInstall]

param(
    [switch]$Release,      # 使用 Release 模式编译
    [switch]$SkipBuild,    # 跳过编译
    [switch]$NoInstall,    # 不安装到设备
    [switch]$NoLaunch      # 不启动应用
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

$appDir = Join-Path $PSScriptRoot "..\app"
$buildMode = if ($Release) { "release" } else { "debug" }
$apkName = "app-dev-$buildMode.apk"
$apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\$apkName"

# =============================================================================
# 1. 生成环境变量
# =============================================================================
Write-Step "1. 检查/生成环境变量文件"

Push-Location $appDir
try {
    $devEnvGenPath = "lib\env\dev_env.g.dart"
    if (-not (Test-Path $devEnvGenPath) -or -not $SkipBuild) {
        Write-Host "   运行 build_runner..."
        dart run build_runner build --delete-conflicting-outputs 2>&1 | Out-Null
        Write-Success "环境变量文件已生成"
    } else {
        Write-Success "环境变量文件已存在"
    }
} finally {
    Pop-Location
}

# =============================================================================
# 2. 编译 APK
# =============================================================================
if (-not $SkipBuild) {
    Write-Step "2. 编译 Flutter APK ($buildMode 模式)"
    
    Push-Location $appDir
    try {
        $buildCmd = "flutter build apk --flavor dev --$buildMode"
        Write-Host "   命令: $buildCmd"
        
        $process = Start-Process -FilePath "flutter" -ArgumentList "build", "apk", "--flavor", "dev", "--$buildMode" -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            throw "Flutter 编译失败"
        }
        
        if (Test-Path $apkPath) {
            $apkInfo = Get-Item $apkPath
            $apkSize = [math]::Round($apkInfo.Length / 1MB, 2)
            Write-Success "APK 编译完成: $apkName ($apkSize MB)"
        } else {
            throw "APK 文件未找到: $apkPath"
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Step "2. 跳过编译 (使用现有 APK)"
    if (Test-Path $apkPath) {
        Write-Success "找到现有 APK: $apkName"
    } else {
        throw "APK 文件不存在: $apkPath"
    }
}

# =============================================================================
# 3. 设置 ADB 端口转发
# =============================================================================
Write-Step "3. 设置 ADB 端口转发"

$adbDevices = adb devices 2>$null | Select-String "device$"
if (-not $adbDevices) {
    throw "未找到 ADB 设备，请连接设备并启用 USB 调试"
}

# 设置端口转发
adb reverse tcp:8000 tcp:8000 2>$null
Write-Success "端口转发已设置: tcp:8000 -> tcp:8000"

# =============================================================================
# 4. 安装 APK
# =============================================================================
if (-not $NoInstall) {
    Write-Step "4. 安装 APK 到设备"
    
    Write-Host "   APK: $apkPath"
    
    # 先尝试卸载旧版本 (忽略错误)
    adb uninstall com.friend.ios.dev 2>$null | Out-Null
    
    # 安装新版本
    $installResult = adb install --user 0 -r -t $apkPath 2>&1
    if ($installResult -match "Success") {
        Write-Success "APK 安装成功"
    } else {
        Write-Host $installResult
        throw "APK 安装失败"
    }
} else {
    Write-Step "4. 跳过安装"
}

# =============================================================================
# 5. 启动应用
# =============================================================================
if (-not $NoLaunch -and -not $NoInstall) {
    Write-Step "5. 启动应用"
    
    # 强制停止旧进程
    adb shell am force-stop com.friend.ios.dev 2>$null
    
    Start-Sleep -Seconds 1
    
    # 启动应用
    $launchResult = adb shell am start -n com.friend.ios.dev/com.friend.ios.MainActivity 2>&1
    if ($launchResult -match "Starting") {
        Write-Success "应用已启动"
    } else {
        Write-Host $launchResult
        Write-Error "应用启动可能失败"
    }
}

# =============================================================================
# 完成
# =============================================================================
Write-Host "`n" -NoNewline
Write-Host "=" * 50 -ForegroundColor Green
Write-Host " 部署完成!" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green

Write-Host "`n提示:"
Write-Host "  - 查看日志: adb logcat -s flutter"
Write-Host "  - 过滤错误: adb logcat *:E | findstr flutter"
Write-Host "  - 停止应用: adb shell am force-stop com.friend.ios.dev"
Write-Host ""
