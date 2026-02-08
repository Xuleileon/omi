$ErrorActionPreference = "Stop"

# 配置
$DOCKERHUB_USERNAME = "rienside2121"  # 改成你的Docker Hub用户名
$IMAGE_NAME = "omi-backend"
$TAG = "latest"
$CACHE_TAG = "buildcache"
$LOCAL_CACHE_DIR = "E:\omi\.docker-cache"  # 本地缓存目录

Write-Host "== Docker Hub Backend Build & Push (ULTRA FAST MODE) ==" -ForegroundColor Cyan
Write-Host "Username: $DOCKERHUB_USERNAME" -ForegroundColor Yellow
Write-Host "Image: $DOCKERHUB_USERNAME/${IMAGE_NAME}:$TAG" -ForegroundColor Yellow
Write-Host ""

# 启用 BuildKit
$env:DOCKER_BUILDKIT = "1"
$env:BUILDKIT_PROGRESS = "plain"

# 创建本地缓存目录
if (-Not (Test-Path $LOCAL_CACHE_DIR)) {
    New-Item -ItemType Directory -Path $LOCAL_CACHE_DIR | Out-Null
    Write-Host "Created local cache directory: $LOCAL_CACHE_DIR" -ForegroundColor Gray
}

# 检查是否登录
Write-Host "== Checking Docker login ==" -ForegroundColor Cyan
docker info | Select-String -Pattern "Username" -Quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Please login to Docker Hub:" -ForegroundColor Yellow
    docker login
}

# 记录开始时间
$StartTime = Get-Date

# 构建镜像（本地缓存 + 远程缓存双保险）
Write-Host "`n== Building image with local + remote cache ==" -ForegroundColor Cyan
Write-Host "Local cache: $LOCAL_CACHE_DIR" -ForegroundColor Gray
Write-Host "Remote cache: $DOCKERHUB_USERNAME/${IMAGE_NAME}:$CACHE_TAG" -ForegroundColor Gray

Push-Location "E:\omi"

docker buildx build `
    --file backend/Dockerfile.prod `
    --tag "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}" `
    --cache-from "type=local,src=${LOCAL_CACHE_DIR}" `
    --cache-from "type=registry,ref=${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${CACHE_TAG}" `
    --cache-to "type=local,dest=${LOCAL_CACHE_DIR},mode=max" `
    --cache-to "type=registry,ref=${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${CACHE_TAG},mode=max" `
    --push `
    --platform linux/amd64 `
    .

Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# 计算耗时
$EndTime = Get-Date
$Duration = $EndTime - $StartTime
$Minutes = [math]::Floor($Duration.TotalMinutes)
$Seconds = $Duration.Seconds

Write-Host "`n== Success! ==" -ForegroundColor Green
Write-Host "Build + Push completed in: ${Minutes}m ${Seconds}s" -ForegroundColor Green
Write-Host "Image: ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}" -ForegroundColor Green
Write-Host ""
Write-Host "Use this in Zeabur Prebuilt:" -ForegroundColor Yellow
Write-Host "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tip: Local cache stored at $LOCAL_CACHE_DIR (can grow large, safe to delete)" -ForegroundColor Gray
