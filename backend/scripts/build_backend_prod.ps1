$ErrorActionPreference = "Stop"

# Build backend image using docker-compose (Dockerfile.prod)
# and verify Torch is not installed in the resulting image.

param(
  [Parameter(Mandatory = $false)]
  [string]$Image = "omi-backend:latest"
)

Write-Host "== Build backend image ==" -ForegroundColor Cyan
Push-Location "e:\omi"
docker compose build backend
Pop-Location

Write-Host "== Image size ==" -ForegroundColor Cyan
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | Select-String -Pattern "omi-backend"

Write-Host "== Verify torch stack absent ==" -ForegroundColor Cyan
docker run --rm $Image python -c "import pkg_resources as pr; names={d.project_name.lower() for d in pr.working_set}; print('torch' in names, 'torchvision' in names, 'torchaudio' in names)"

Write-Host "== OK ==" -ForegroundColor Green

