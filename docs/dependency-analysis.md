# Omi 后端依赖分析报告

## 执行摘要

当前 `requirements.txt` 包含 **259 个依赖**，Docker 镜像大小约 **4.5GB**。

通过分析，可将生产镜像大小降低到 **~1.5-2GB**（减少 55-67%）。

---

## 架构发现

### 关键发现：双重部署模式

后端设计支持两种部署模式：

| 模式 | 用途 | GPU | 重型AI |
|------|------|-----|--------|
| **Modal.com** | 官方生产环境 | ✅ 支持 | ✅ 本地运行 |
| **Docker/Zeabur** | 自托管/私有部署 | ❌ 仅CPU | ❌ 远程API |

```
main.py (line 112-129):
├─ modal_app = App(name='backend')
├─ image = Image.debian_slim().pip_install_from_requirements('requirements.txt')
└─ @modal_app.function(image=image, ...)
   └─ api() -> FastAPI app
```

### AI工作负载分流设计

| 功能 | 本地模式 | 生产模式（推荐） |
|------|----------|------------------|
| VAD (语音活动检测) | Silero (PyTorch) | `HOSTED_VAD_API_URL` (远程API) |
| Speaker Embedding | SpeechBrain | `HOSTED_SPEAKER_EMBEDDING_API_URL` |
| Diarization | Pyannote (本地) | 单独 `diarizer/` Docker 镜像 |

**结论**：生产部署应使用远程API，本地PyTorch/Pyannote/SpeechBrain是可选的开发/后备功能。

---

## 依赖分析

### 🔴 可完全移除（生产环境不需要）

| 包名 | 大小估计 | 原因 |
|------|----------|------|
| `pyannote.*` (5个包) | ~500MB | 仅用于本地diarization，生产用远程API或单独镜像 |
| `speechbrain` | ~200MB | 仅用于本地speaker embedding，生产用远程API |
| `torch` (2.4.0 GPU版) | ~2GB | GPU版本，CPU部署完全不需要 |
| `torchvision` | ~500MB | 图像处理，Omi不需要 |
| `torchaudio` | ~100MB | 仅本地speaker embedding需要 |
| `pytorch-lightning` | ~50MB | speechbrain依赖 |
| `pytorch-metric-learning` | ~30MB | speechbrain依赖 |
| `lightning` | ~50MB | speechbrain依赖 |
| `asteroid-filterbanks` | ~10MB | pyannote依赖 |
| `julius` | ~5MB | pyannote依赖 |

**潜在节省：~3.4GB**

### 🟡 开发/脚本依赖（生产可移除）

| 包名 | 大小估计 | 用途 |
|------|----------|------|
| `streamlit` | ~100MB | 仅 `scripts/` 中使用 |
| `altair` | ~20MB | Streamlit可视化 |
| `plotly` | ~30MB | 数据可视化 |
| `matplotlib` | ~50MB | 图表绘制 |
| `mplcursors` | ~5MB | matplotlib扩展 |
| `mpld3` | ~5MB | matplotlib扩展 |
| `ipython` | ~20MB | 交互式开发 |
| `pandas` | ~50MB | 仅脚本中使用（检查是否routers也用） |

**潜在节省：~280MB**

### 🟢 核心依赖（必须保留）

| 类别 | 包名 | 用途 |
|------|------|------|
| **Web框架** | fastapi, uvicorn, starlette | API服务 |
| **数据库** | firebase-admin, google-cloud-firestore, redis, pinecone | 数据存储 |
| **LLM** | langchain*, openai, groq | AI聊天 |
| **音频处理** | pydub, pyogg, opuslib, lc3py | 音频编解码 |
| **STT** | deepgram-sdk, soniox, speechmatics-python | 语音转文字 |
| **存储** | google-cloud-storage | 文件存储 |
| **认证** | PyJWT, cryptography | 安全认证 |

### 🔵 可选：保留轻量版本

| 当前 | 替换为 | 节省 |
|------|--------|------|
| `torch==2.4.0` (GPU) | `torch==2.4.0+cpu` | ~1.5GB |
| `onnxruntime==1.19.0` | 保留（Silero VAD用） | 0 |

如果要保留本地 Silero VAD 功能，可以只用 CPU 版 PyTorch (~200MB)。

---

## 未使用的依赖（需验证）

以下依赖在代码中**未发现直接导入**：

| 包名 | 可能原因 |
|------|----------|
| `langchain-huggingface` | 可能是 langchain 的间接依赖 |
| `sentence-transformers` | 未直接使用，可能遗留 |
| `assemblyai` | 可能已废弃的 STT 选项 |
| `neo4j` | Knowledge Graph 可能已移除 |
| `optuna` | ML超参数优化，可能遗留 |
| `tensorboardX` | 训练监控，生产不需要 |

---

## 架构问题分析

### 1. VAD 位置问题 ⚠️

**当前状态**：
- 服务端运行 Silero VAD（需要 PyTorch）
- 客户端通过 WebSocket 持续发送音频流

**问题**：
- 浪费带宽传输静音
- 服务端 CPU/内存开销
- 增加延迟

**建议方案**（参考 `openplaud` 项目）：
```
客户端架构：
├─ Level 0: 完全休眠 (0%功耗)
├─ Level 1: 音量阈值检测 (0.3%/h)
├─ Level 2: 轻量VAD (WebRTC GMM) (1%/h)
└─ Level 3: 全量录音+上传 (3-5%/h)
```

**移除服务端 VAD 后**：
- ✅ 移除 PyTorch 依赖
- ✅ 镜像大小减少 ~2GB
- ✅ 运行时内存减少 ~500MB

### 2. Modal.com 集成的影响

`main.py` 包含 Modal.com 部署配置：
```python
modal_app = App(name='backend')
image = Image.debian_slim().pip_install_from_requirements('requirements.txt')
```

**问题**：
- 所有依赖都打包进 Modal 镜像
- 即使生产用远程API，依赖仍被安装

**建议**：
- 分离 `requirements.txt`（核心）和 `requirements-dev.txt`（开发/Modal）
- 或使用 `requirements.prod.txt`（已创建）

### 3. Diarizer 单独镜像

`backend/diarizer/` 已有独立的：
- `requirements.txt`（含 pyannote）
- `Dockerfile`

**说明**：生产环境 Diarization 应该用这个单独的服务，主后端不需要 pyannote。

---

## 推荐的生产 requirements.prod.txt

```txt
# === Web Framework ===
fastapi==0.112.0
uvicorn==0.30.5
starlette==0.37.2

# === Database & Storage ===
firebase-admin==6.5.0
google-cloud-firestore==2.17.0
google-cloud-storage==2.18.0
redis==5.0.8
pinecone==7.3.0

# === LLM & Chat ===
langchain==0.3.27
langchain-community==0.3.31
langchain-core==0.3.79
langchain-openai==0.3.35
langchain-pinecone==0.2.12
langgraph==0.6.10
openai==1.104.2

# === STT Services ===
deepgram-sdk==4.8.1
soniox==1.10.1
speechmatics-python==2.0.1

# === Audio Processing (必需) ===
pydub==0.25.1
opuslib==3.0.1
lc3py==1.1.3
PyOgg @ git+https://github.com/TeamPyOgg/PyOgg@6871a4f234e8a3a346c4874a12509bfa02c4c63a

# === Auth & Security ===
PyJWT==2.9.0
cryptography==43.0.0

# === Utilities ===
pydantic==2.8.2
pydantic-settings==2.10.1
python-dotenv==1.0.1
requests~=2.32.5
aiohttp==3.9.5
httpx==0.28.0
websockets==12.0

# === 可选：本地 Silero VAD (CPU) ===
# 如果需要本地VAD，取消以下注释：
# --extra-index-url https://download.pytorch.org/whl/cpu
# torch==2.4.0+cpu
# onnxruntime==1.19.0
# numpy==1.26.4
# webrtcvad==2.0.10

# === 其他必需 ===
posthog==3.5.2
stripe==11.3.0
```

---

## 行动计划

### Phase 1: 快速瘦身（立即可做）

1. ✅ 创建 `requirements.prod.txt`
2. ✅ 创建 `Dockerfile.prod`
3. ⬜ 测试无 PyTorch 镜像是否能启动
4. ⬜ 验证 `HOSTED_VAD_API_URL` 是否正确配置

### Phase 2: 客户端 VAD（中期）

1. ⬜ 实现 Android 端音量阈值检测
2. ⬜ 实现 WebRTC VAD 或 Silero ONNX
3. ⬜ 只发送有语音的音频段
4. ⬜ 移除服务端 VAD 依赖

### Phase 3: 架构优化（长期）

1. ⬜ 分离 Modal 部署配置
2. ⬜ 清理未使用的依赖
3. ⬜ 优化音频编码（Opus 替代 PCM16）

---

## 镜像大小对比

| 版本 | 大小 | 减少 |
|------|------|------|
| 当前（含 GPU PyTorch） | 4.53 GB | - |
| 移除 GPU 依赖 | ~2.5 GB | -45% |
| 完全移除 PyTorch/Pyannote | **~1.5 GB** | **-67%** |

---

## 相关文件

- `backend/requirements.txt` - 当前完整依赖
- `backend/requirements.prod.txt` - 生产精简依赖
- `backend/Dockerfile.prod` - 生产 Dockerfile
- `backend/diarizer/` - 独立 Diarization 服务
- `backend/modal/` - Modal.com 部署脚本
- `openplaud/docs/architecture/POWER_OPTIMIZATION.md` - 客户端 VAD 方案

---

**生成时间**: 2026-02-05
**作者**: AI Assistant
