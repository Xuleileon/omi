# Omi 部署测试脚本
# 用法: .\scripts\test-deployment.ps1

param(
    [string]$BackendHost = "127.0.0.1",
    [string]$BackendPort = "8000",
    [switch]$SkipDocker,
    [switch]$SkipFlutter,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$script:TestResults = @()

function Write-TestHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $status = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status " -ForegroundColor $color -NoNewline
    Write-Host "$TestName" -NoNewline
    if ($Message) {
        Write-Host " - $Message" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
    
    $script:TestResults += @{
        Name = $TestName
        Passed = $Passed
        Message = $Message
    }
}

# =============================================================================
# 1. 环境检查
# =============================================================================
Write-TestHeader "1. 环境检查"

# 检查 Docker
$dockerVersion = docker --version 2>$null
if ($dockerVersion) {
    Write-TestResult "Docker 安装" $true $dockerVersion
} else {
    Write-TestResult "Docker 安装" $false "未找到 Docker"
}

# 检查 Flutter
$flutterVersion = flutter --version 2>$null | Select-String "Flutter"
if ($flutterVersion) {
    Write-TestResult "Flutter 安装" $true $flutterVersion
} else {
    Write-TestResult "Flutter 安装" $false "未找到 Flutter"
}

# 检查 ADB
$adbVersion = adb version 2>$null | Select-String "Android Debug Bridge"
if ($adbVersion) {
    Write-TestResult "ADB 安装" $true
} else {
    Write-TestResult "ADB 安装" $false "未找到 ADB"
}

# 检查 Firebase CLI
$firebaseVersion = firebase --version 2>$null
if ($firebaseVersion) {
    Write-TestResult "Firebase CLI" $true "v$firebaseVersion"
} else {
    Write-TestResult "Firebase CLI" $false "未找到 Firebase CLI"
}

# 检查 gcloud
$gcloudVersion = gcloud version 2>$null | Select-String "Google Cloud SDK"
if ($gcloudVersion) {
    Write-TestResult "Google Cloud CLI" $true
} else {
    Write-TestResult "Google Cloud CLI" $false "未找到 gcloud"
}

# =============================================================================
# 2. 配置文件检查
# =============================================================================
Write-TestHeader "2. 配置文件检查"

$configFiles = @(
    @{ Path = "backend\.env"; Required = $true; Name = "后端环境变量" },
    @{ Path = "app\.dev.env"; Required = $true; Name = "前端环境变量" },
    @{ Path = "backend\firestore.indexes.json"; Required = $true; Name = "Firestore 索引" },
    @{ Path = "backend\firebase.json"; Required = $true; Name = "Firebase 配置" },
    @{ Path = "docker-compose.yml"; Required = $false; Name = "Docker Compose" }
)

foreach ($config in $configFiles) {
    $fullPath = Join-Path $PSScriptRoot "..\$($config.Path)"
    $exists = Test-Path $fullPath
    $status = if ($exists) { $true } else { $false }
    $msg = if (-not $exists -and $config.Required) { "必需但缺失!" } elseif (-not $exists) { "可选" } else { "" }
    Write-TestResult $config.Name $status $msg
}

# 检查后端 .env 内容
$backendEnvPath = Join-Path $PSScriptRoot "..\backend\.env"
if (Test-Path $backendEnvPath) {
    $envContent = Get-Content $backendEnvPath -Raw
    
    $requiredVars = @(
        "OPENAI_API_KEY",
        "DEEPGRAM_API_KEY",
        "FIREBASE_PROJECT_ID",
        "PINECONE_API_KEY",
        "REDIS_DB_HOST",
        "REDIS_DB_PASSWORD"
    )
    
    foreach ($var in $requiredVars) {
        $hasVar = $envContent -match "$var=.+"
        Write-TestResult "  ENV: $var" $hasVar
    }
}

# =============================================================================
# 3. Docker 服务检查
# =============================================================================
if (-not $SkipDocker) {
    Write-TestHeader "3. Docker 服务检查"
    
    $containers = docker ps --format "{{.Names}}" 2>$null
    
    $expectedContainers = @("omi-backend-1", "redis-crawler")
    foreach ($container in $expectedContainers) {
        $running = $containers -contains $container
        Write-TestResult "容器: $container" $running $(if (-not $running) { "未运行" } else { "运行中" })
    }
    
    # 检查容器健康状态
    if ($containers -contains "omi-backend-1") {
        $health = docker inspect --format='{{.State.Health.Status}}' omi-backend-1 2>$null
        if (-not $health) { $health = "unknown" }
        Write-TestResult "后端健康状态" ($health -eq "healthy" -or $health -eq "unknown") $health
    }
}

# =============================================================================
# 4. 后端 API 检查
# =============================================================================
Write-TestHeader "4. 后端 API 检查"

$baseUrl = "http://${BackendHost}:${BackendPort}"

# 健康检查
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/" -Method GET -TimeoutSec 5 -UseBasicParsing
    Write-TestResult "API 根路径" ($response.StatusCode -eq 200) "HTTP $($response.StatusCode)"
} catch {
    Write-TestResult "API 根路径" $false $_.Exception.Message
}

# 对话列表 API
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/v1/conversations?limit=1" -Method GET -TimeoutSec 10 -UseBasicParsing
    Write-TestResult "对话列表 API" ($response.StatusCode -eq 200) "HTTP $($response.StatusCode)"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401 -or $statusCode -eq 403) {
        Write-TestResult "对话列表 API" $true "需要认证 (HTTP $statusCode)"
    } else {
        Write-TestResult "对话列表 API" $false $_.Exception.Message
    }
}

# 应用分类 API
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/v1/app-categories" -Method GET -TimeoutSec 10 -UseBasicParsing
    Write-TestResult "应用分类 API" ($response.StatusCode -eq 200) "HTTP $($response.StatusCode)"
} catch {
    Write-TestResult "应用分类 API" $false $_.Exception.Message
}

# =============================================================================
# 5. 外部服务检查
# =============================================================================
Write-TestHeader "5. 外部服务检查"

# 检查 Upstash Redis (从 .env 读取)
if (Test-Path $backendEnvPath) {
    $envContent = Get-Content $backendEnvPath -Raw
    if ($envContent -match 'REDIS_DB_HOST=(.+)') {
        $redisHost = $matches[1].Trim()
        if ($envContent -match 'REDIS_DB_PASSWORD=(.+)') {
            $redisPassword = $matches[1].Trim()
            
            try {
                $redisUrl = "https://$redisHost/ping"
                $headers = @{
                    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("default:$redisPassword"))
                }
                $response = Invoke-WebRequest -Uri $redisUrl -Headers $headers -TimeoutSec 5 -UseBasicParsing
                $result = $response.Content | ConvertFrom-Json
                Write-TestResult "Upstash Redis" ($result.result -eq "PONG") $result.result
            } catch {
                Write-TestResult "Upstash Redis" $false $_.Exception.Message
            }
        }
    }
}

# 检查 Firebase/Firestore
if ($envContent -match 'FIREBASE_PROJECT_ID=(.+)') {
    $projectId = $matches[1].Trim()
    try {
        # 简单检查项目是否存在
        $response = Invoke-WebRequest -Uri "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents" -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
        Write-TestResult "Firestore 连接" $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 403 -or $statusCode -eq 401) {
            Write-TestResult "Firestore 连接" $true "需要认证"
        } else {
            Write-TestResult "Firestore 连接" $false $_.Exception.Message
        }
    }
}

# =============================================================================
# 6. ADB 设备检查
# =============================================================================
Write-TestHeader "6. ADB 设备检查"

$adbDevices = adb devices 2>$null | Select-String "device$"
if ($adbDevices) {
    Write-TestResult "ADB 设备连接" $true "$($adbDevices.Count) 个设备"
    
    # 检查端口转发
    $reverseList = adb reverse --list 2>$null
    $hasReverse = $reverseList -match "tcp:8000"
    Write-TestResult "ADB 端口转发 (8000)" $hasReverse $(if (-not $hasReverse) { "运行: adb reverse tcp:8000 tcp:8000" })
    
    # 检查应用安装
    $packages = adb shell pm list packages 2>$null | Select-String "com.friend.ios"
    Write-TestResult "Omi 应用安装" ($packages -ne $null)
} else {
    Write-TestResult "ADB 设备连接" $false "无设备连接"
}

# =============================================================================
# 7. Flutter 项目检查
# =============================================================================
if (-not $SkipFlutter) {
    Write-TestHeader "7. Flutter 项目检查"
    
    $appDir = Join-Path $PSScriptRoot "..\app"
    
    # 检查生成文件
    $genFiles = @(
        "lib\env\dev_env.g.dart",
        "lib\env\env.g.dart"
    )
    
    foreach ($genFile in $genFiles) {
        $fullPath = Join-Path $appDir $genFile
        $exists = Test-Path $fullPath
        Write-TestResult "生成文件: $genFile" $exists $(if (-not $exists) { "运行: dart run build_runner build" })
    }
    
    # 检查 APK
    $apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-dev-debug.apk"
    $apkExists = Test-Path $apkPath
    if ($apkExists) {
        $apkInfo = Get-Item $apkPath
        $apkSize = [math]::Round($apkInfo.Length / 1MB, 2)
        Write-TestResult "Debug APK" $true "$apkSize MB"
    } else {
        Write-TestResult "Debug APK" $false "运行: flutter build apk --flavor dev --debug"
    }
    
    $releaseApkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-dev-release.apk"
    $releaseExists = Test-Path $releaseApkPath
    if ($releaseExists) {
        $releaseInfo = Get-Item $releaseApkPath
        $releaseSize = [math]::Round($releaseInfo.Length / 1MB, 2)
        Write-TestResult "Release APK" $true "$releaseSize MB"
    } else {
        Write-TestResult "Release APK" $false "运行: flutter build apk --flavor dev --release"
    }
}

# =============================================================================
# 测试总结
# =============================================================================
Write-TestHeader "测试总结"

$passed = ($script:TestResults | Where-Object { $_.Passed }).Count
$failed = ($script:TestResults | Where-Object { -not $_.Passed }).Count
$total = $script:TestResults.Count

Write-Host "`n通过: " -NoNewline
Write-Host $passed -ForegroundColor Green -NoNewline
Write-Host " / 失败: " -NoNewline
Write-Host $failed -ForegroundColor Red -NoNewline
Write-Host " / 总计: $total"

if ($failed -gt 0) {
    Write-Host "`n失败的测试:" -ForegroundColor Yellow
    $script:TestResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Red
        if ($_.Message) {
            Write-Host "    $($_.Message)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n"

# 返回退出码
if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
