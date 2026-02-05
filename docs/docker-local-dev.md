# Docker Compose 本地开发设置

## 快速开始

1. 复制环境变量模板：
```bash
cp .env.docker.template .env.docker
```

2. 编辑`.env.docker`，填入你的本地路径：

**Windows用户**：
```bash
GOOGLE_CREDENTIALS_PATH=C:/Users/YOUR_USERNAME/AppData/Roaming/gcloud/application_default_credentials.json
HF_CACHE_PATH=C:/Users/YOUR_USERNAME/.cache/huggingface
```

**macOS/Linux用户**：
```bash
GOOGLE_CREDENTIALS_PATH=~/.config/gcloud/application_default_credentials.json
HF_CACHE_PATH=~/.cache/huggingface
```

3. 启动服务：
```bash
docker-compose --env-file .env.docker up
```

## 获取Google Cloud凭证

如果你还没有本地凭证：

```bash
gcloud auth application-default login
```

凭证会自动保存到：
- Windows: `%APPDATA%\gcloud\application_default_credentials.json`
- macOS/Linux: `~/.config/gcloud/application_default_credentials.json`

## 安全注意事项

⚠️ **永远不要提交以下文件**：
- `.env.docker` (你的本地环境变量)
- `backend/.env` (后端密钥)
- `google-credentials.json` (服务账号密钥)
- `*.jks` (Android签名密钥)

✅ **可以提交的模板文件**：
- `.env.template`
- `.env.docker.template`

## 故障排除

### 凭证文件找不到
确保路径使用正斜杠 `/`，即使在Windows上也是：
```bash
# 正确
C:/Users/dingx/AppData/Roaming/gcloud/...

# 错误
C:\Users\dingx\AppData\Roaming\gcloud\...
```

### 权限问题
确保Docker有权访问挂载的目录。在Docker Desktop设置中添加文件共享路径。
