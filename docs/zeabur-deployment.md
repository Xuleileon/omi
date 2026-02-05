# Zeabur 部署指南

## 1. 准备工作

### 1.1 环境变量
确保已配置以下环境变量：

```env
# LLM 配置
OPENAI_API_KEY=your-api-key
OPENAI_API_BASE=https://api.openai.com/v1  # 或代理 API
OPENAI_MODEL=gpt-4o-mini  # 或 claude-sonnet-4-5-20250929

# 语音转文字
DEEPGRAM_API_KEY=your-deepgram-key

# Firebase
FIREBASE_PROJECT_ID=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json

# Pinecone 向量库
PINECONE_API_KEY=your-pinecone-key
PINECONE_INDEX_NAME=omi-memories

# Redis (Upstash)
REDIS_DB_HOST=your-redis.upstash.io
REDIS_DB_PORT=6379
REDIS_DB_PASSWORD=your-redis-password
```

### 1.2 Firebase 服务账号
1. 前往 Firebase Console → 项目设置 → 服务账号
2. 点击"生成新的私钥"
3. 将 JSON 文件保存为 `backend/service-account.json`
4. 在 Zeabur 中作为文件上传或设置为环境变量

## 2. Zeabur 部署步骤

### 2.1 创建项目
1. 登录 [Zeabur](https://zeabur.com)
2. 创建新项目
3. 选择 "Deploy from GitHub"
4. 选择你的 Omi 仓库

### 2.2 配置服务
1. **Root Directory**: 设置为 `backend`
2. **Service Type**: Docker
3. **Port**: 8000
4. **Health Check**: `/`

### 2.3 添加环境变量
在 Zeabur 控制台添加上述所有环境变量

### 2.4 文件挂载 (可选)
如果使用 service-account.json 文件：
- 挂载路径: `/app/service-account.json`
- 或使用 `GOOGLE_APPLICATION_CREDENTIALS_JSON` 环境变量存储 JSON 内容

## 3. Dockerfile 配置

确保 `backend/Dockerfile` 包含：

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY . .

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## 4. 前端配置

部署成功后，获取 Zeabur 提供的域名（如 `your-app.zeabur.app`），然后：

1. 更新前端 `.dev.env`:
```env
API_BASE_URL=https://your-app.zeabur.app/
```

2. 重新编译前端:
```bash
cd app
dart run build_runner build --delete-conflicting-outputs
flutter build apk --flavor dev --release
```

## 5. 验证部署

```bash
# 健康检查
curl https://your-app.zeabur.app/

# 测试 API
curl https://your-app.zeabur.app/v1/app-categories
```

## 6. 常见问题

### 部署失败
- 检查 Dockerfile 语法
- 确保所有环境变量已设置
- 查看 Zeabur 部署日志

### Firebase 认证失败
- 确保 `FIREBASE_PROJECT_ID` 正确
- 确保服务账号有正确的权限
- 检查 `GOOGLE_APPLICATION_CREDENTIALS` 路径

### Redis 连接失败
- Upstash 需要 TLS，确保代码中 `ssl=True`
- 检查密码和主机名

## 7. 性能优化

### 多 Worker 部署
```dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

### 自动扩缩
在 Zeabur 设置中配置：
- Min instances: 1
- Max instances: 5
- CPU threshold: 70%

---

*最后更新: 2026-02-05*
