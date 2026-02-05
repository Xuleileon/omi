# Omi 项目部署总结文档

## 1. 项目概述

Omi 是一个多模态 AI 可穿戴平台，包含以下核心组件：

| 组件 | 技术栈 | 位置 |
|------|--------|------|
| 后端 | Python/FastAPI | `backend/` |
| 移动端 | Flutter/Dart | `app/` |
| 固件 | C/C++ (Zephyr/Arduino) | `omi/`, `omiGlass/` |
| Web | Next.js/TypeScript | `web/` |
| 插件 | Python/Node.js | `plugins/` |

## 2. 环境配置

### 2.1 后端环境变量 (`backend/.env`)

```env
# LLM 配置
OPENAI_API_KEY=<your-openai-api-key>
OPENAI_API_BASE=https://api.openai.com/v1  # 或兼容的API地址

# 语音转文字
DEEPGRAM_API_KEY=<your-deepgram-api-key>

# Firebase
FIREBASE_PROJECT_ID=<your-project-id>
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

# 向量数据库 (Pinecone)
PINECONE_API_KEY=<your-pinecone-api-key>
PINECONE_INDEX_NAME=omi-memories

# Redis 缓存 (Upstash - 需要TLS)
REDIS_DB_HOST=<your-redis-host>.upstash.io
REDIS_DB_PORT=6379
REDIS_DB_PASSWORD=<your-redis-password>
```

### 2.2 前端环境变量 (`app/.dev.env`)

```env
API_BASE_URL=http://127.0.0.1:8000/
FIREBASE_PROJECT_ID=<your-project-id>
FIREBASE_STORAGE_BUCKET=<your-project-id>.appspot.com
FIREBASE_ANDROID_API_KEY=<your-android-api-key>
FIREBASE_IOS_API_KEY=<your-ios-api-key>
FIREBASE_APP_ID=<your-app-id>
FIREBASE_MESSAGING_SENDER_ID=<your-sender-id>
GROWTHBOOK_API_KEY=<optional>
MIXPANEL_TOKEN=<optional>
INTERCOM_APP_ID=<optional>
INTERCOM_IOS_API_KEY=<optional>
INTERCOM_ANDROID_API_KEY=<optional>
```

## 3. 服务依赖

### 3.1 Google Cloud / Firebase

| 服务 | 用途 | 配置状态 |
|------|------|----------|
| Firestore API | 数据库 | ✅ 需启用 |
| Firestore 数据库 | 存储对话/记忆 | ✅ 需创建 |
| Firestore 索引 | 查询优化 | ✅ 需部署 |
| Firebase Auth | 用户认证 | ✅ 需配置 |
| Cloud Storage | 文件存储 | ✅ 需配置 |

### 3.2 第三方服务

| 服务 | 用途 | 必需 |
|------|------|------|
| OpenAI/兼容API | LLM 推理 | ✅ 是 |
| Deepgram | 语音转文字 | ✅ 是 |
| Pinecone | 向量搜索 | ✅ 是 |
| Upstash Redis | 缓存/Pub-Sub | ✅ 是 |
| Intercom | 客服 | ❌ 否 |
| Mixpanel | 分析 | ❌ 否 |

## 4. 部署步骤

### 4.1 启用 Google Cloud 服务

```bash
# 启用 Firestore API
gcloud services enable firestore.googleapis.com --project=<project-id>

# 创建 Firestore 数据库
gcloud firestore databases create --project=<project-id> --location=nam5 --type=firestore-native
```

### 4.2 部署 Firestore 索引

```bash
# 在 backend/ 目录下
firebase deploy --only firestore:indexes --project <project-id>
```

索引文件位置: `backend/firestore.indexes.json`

**必需的索引**:
1. `conversations` 集合: `status` (ASC) + `created_at` (DESC)
2. `conversations` 集合: `discarded` (ASC) + `status` (ASC) + `created_at` (DESC) 
3. `messages` 集合: `plugin_id` (ASC) + `created_at` (DESC)
4. `messages` 集合: `chat_session_id` (ASC) + `plugin_id` (ASC) + `created_at` (DESC)
5. `memories` 集合: `scoring` (DESC) + `created_at` (DESC) ← AI 记忆检索必需

**注意**: 索引创建可能需要几分钟时间

### 已知问题修复

#### 1. 代理 API 结构化输出不兼容
如果使用代理 API (如 `gptclubapi.xyz`) 而不是原生 OpenAI API：
- `with_structured_output()` 可能不工作（返回纯文本而非 JSON）
- 已在 `utils/llm/chat.py` 中添加回退逻辑
- 如果结构化输出失败，会自动使用纯文本解析

#### 2. Graph 硬编码模型问题 (关键修复)
**问题**: `utils/retrieval/graph.py` 原本硬编码了 OpenAI 模型名称：
```python
# 原始代码 - 错误
model = ChatOpenAI(model="gpt-4.1-mini")
llm_medium_stream = ChatOpenAI(model='gpt-4.1', streaming=True)
```

**修复**: 改为使用 `clients.py` 中环境变量配置的模型：
```python
# 修复后 - 正确
from utils.llm.clients import llm_mini as model, llm_medium_stream
```

这确保所有 LLM 调用都使用 `backend/.env` 中配置的 `OPENAI_API_KEY`、`OPENAI_API_BASE` 和 `OPENAI_MODEL`

### 4.3 启动后端

```bash
# 使用 Docker
docker-compose up -d

# 或直接启动
cd backend && python main.py
```

### 4.4 编译前端

```bash
cd app

# 生成环境变量
dart run build_runner build --delete-conflicting-outputs

# Debug 编译 (含断言检查)
flutter build apk --flavor dev --debug

# Release 编译 (推荐，无断言)
flutter build apk --flavor dev --release
```

### 4.5 安装到设备

```bash
# 设置端口转发 (允许手机通过 127.0.0.1 访问本地后端)
adb reverse tcp:8000 tcp:8000

# 安装 APK
adb install --user 0 -r -t build/app/outputs/flutter-apk/app-dev-debug.apk

# 启动应用
adb shell am start -n com.friend.ios.dev/com.friend.ios.MainActivity
```

## 5. 常见问题及解决方案

### 5.1 MouseTracker 断言错误 (Debug模式卡死)

**症状**: 应用卡顿/闪退，日志显示 `MouseTracker._shouldMarkStateDirty` assertion failed

**原因**: Flutter Debug 模式的断言检查

**解决**: 使用 Release 模式编译
```bash
flutter build apk --flavor dev --release
```

### 5.2 Redis 连接失败 (WRONGPASS)

**症状**: `WRONGPASS invalid or missing auth token`

**原因**: Upstash Redis 需要 TLS 连接

**解决**: 在 `database/redis_db.py` 中添加 `ssl=True`

### 5.3 Firestore 索引缺失

**症状**: `The query requires an index`

**解决**:
```bash
# 部署索引
firebase deploy --only firestore:indexes --project <project-id>

# 检查索引状态
gcloud firestore indexes composite list --project=<project-id> --format="table(name,state,fields.fieldPath)"
```

**注意**: 新索引可能需要几分钟才能变为 READY 状态

### 5.6 AI 显示 "thinking" 但不回复

**症状**: 聊天界面显示思考中但 AI 不回复

**可能原因**:
1. Firestore 索引尚未就绪 (CREATING 状态)
2. LLM API 配置问题
3. 流式响应中断

**解决**:
1. 检查索引状态: `gcloud firestore indexes composite list`
2. 检查后端日志: `docker logs omi-backend-1`
3. 确认 `OPENAI_API_KEY` 和 `OPENAI_API_BASE` 正确配置

### 5.4 API 连接失败

**症状**: `Connection closed before full header was received`

**解决**:
1. 确保 `API_BASE_URL` 末尾有斜杠: `http://127.0.0.1:8000/`
2. 设置 ADB 端口转发: `adb reverse tcp:8000 tcp:8000`
3. 检查防火墙规则

### 5.5 通知频道组错误

**症状**: `Channel group channel_group_key does not exist`

**解决**: 确保 `NotificationChannelGroup` 的 `channelGroupKey` 与频道定义一致

## 6. 架构要点

### 6.1 数据流

```
设备 → BLE → App → WebSocket → 后端 → STT → 转录 → LLM → Firestore + Pinecone
```

### 6.2 存储架构

- **Firestore**: 对话、记忆、用户数据
- **Pinecone**: 向量嵌入 (语义搜索)
- **Redis**: 缓存 (语音配置、应用状态)
- **GCS**: 二进制文件 (音频、照片)

### 6.3 后端模块层次

```
1. database/  ← 最底层
2. utils/
3. routers/
4. main.py    ← 最顶层
```

**规则**: 高层可导入低层，低层不可导入高层

## 7. 测试命令

```bash
# 后端测试
cd backend && ./test.sh

# 前端测试
cd app && ./test.sh

# API 健康检查
curl http://localhost:8000/

# Redis 连接测试
curl -s -u default:<password> https://<host>.upstash.io:443/ping
```

## 8. 文件清单

| 文件 | 用途 |
|------|------|
| `backend/.env` | 后端环境变量 |
| `app/.dev.env` | 前端环境变量 |
| `backend/firestore.indexes.json` | Firestore 索引定义 |
| `backend/firebase.json` | Firebase CLI 配置 |
| `docker-compose.yml` | Docker 服务编排 |
| `backend/database/redis_db.py` | Redis 连接配置 |

## 9. 线上部署选项

### Zeabur (推荐)
详细步骤见 `docs/zeabur-deployment.md`

**快速步骤**:
1. 创建 Zeabur 项目
2. 连接 GitHub 仓库
3. 设置 Root Directory 为 `backend`
4. 配置环境变量
5. 部署

### Google Cloud Run
```bash
# 构建镜像
gcloud builds submit --tag gcr.io/PROJECT_ID/omi-backend

# 部署
gcloud run deploy omi-backend \
  --image gcr.io/PROJECT_ID/omi-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## 10. 性能说明

### 响应速度
- **正常预期**: AI 回复可能需要 5-30 秒
- **影响因素**:
  - LLM 模型选择（Claude Sonnet 比 GPT 更强但稍慢）
  - 代理 API 网络延迟
  - 本地开发环境的 ADB 端口转发

### 优化建议
1. 使用生产环境部署减少网络跳数
2. 考虑使用更快的模型（如 GPT-4o-mini）
3. 部署到云服务器减少延迟

---

*文档生成时间: 2026-02-05*
*最后更新: 修复 graph.py 硬编码模型问题*
