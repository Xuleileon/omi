$ErrorActionPreference = "Stop"

# 配置
$DOCKERHUB_USERNAME = "yourusername"  # 改成你的Docker Hub用户名
$IMAGE_NAME = "omi-backend"
$TAG = "latest"
$CACHE_TAG = "buildcache"

Write-Host "== Docker Hub Backend Build & Push (FAST MODE) ==" -ForegroundColor Cyan
Write-Host "Username: $DOCKERHUB_USERNAME" -ForegroundColor Yellow
Write-Host "Image: $DOCKERHUB_USERNAME/${IMAGE_NAME}:$TAG" -ForegroundColor Yellow
Write-Host ""

# 启用 BuildKit (更快的构建)
$env:DOCKER_BUILDKIT = "1"
$env:BUILDKIT_PROGRESS = "plain"

# 检查是否登录
Write-Host "== Checking Docker login ==" -ForegroundColor Cyan
docker info | Select-String -Pattern "Username" -Quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Please login to Docker Hub:" -ForegroundColor Yellow
    docker login
}

# 记录开始时间
$StartTime = Get-Date

# 构建镜像（使用 BuildKit + 远程缓存）
Write-Host "`n== Building image with cache ==" -ForegroundColor Cyan
Write-Host "Using cache from: $DOCKERHUB_USERNAME/${IMAGE_NAME}:$CACHE_TAG" -ForegroundColor Gray

Push-Location "E:\omi"

docker buildx build `
    --file backend/Dockerfile.prod `
    --tag "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}" `
    --cache-from "type=registry,ref=${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${CACHE_TAG}" `
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
