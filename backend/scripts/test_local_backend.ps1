param(
  [Parameter(Mandatory = $false)]
  [switch]$SkipBuild = $false
)
 
$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$BackendEnvPath = Join-Path $ProjectRoot "backend\.env"
 
if (-not (Test-Path $BackendEnvPath)) {
  Write-Host "backend/.env 不存在，无法读取 GOOGLE_CREDENTIALS_PATH" -ForegroundColor Red
  exit 1
}
 
$envContent = Get-Content $BackendEnvPath -Raw
if ($envContent -match 'GOOGLE_CREDENTIALS_PATH=(.+)') {
  $credPath = $matches[1].Trim()
} else {
  Write-Host "backend/.env 未配置 GOOGLE_CREDENTIALS_PATH" -ForegroundColor Red
  exit 1
}
 
if (-not (Test-Path $credPath)) {
  Write-Host "凭证文件不存在: $credPath" -ForegroundColor Red
  exit 1
}
 
Write-Host "== 后端容器构建/启动 ==" -ForegroundColor Cyan
Push-Location $ProjectRoot
if ($SkipBuild) {
  docker compose up -d backend
} else {
  docker compose up -d --build backend
}
Pop-Location
 
Start-Sleep -Seconds 2
 
Write-Host "== 健康检查 /v1/health ==" -ForegroundColor Cyan
try {
  $resp = Invoke-WebRequest -Uri "http://localhost:8000/v1/health" -Method GET -TimeoutSec 5 -UseBasicParsing
  Write-Host "Health OK: HTTP $($resp.StatusCode)" -ForegroundColor Green
} catch {
  Write-Host "Health FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
