## Backend 镜像瘦身（去 Torch / 去本地 VAD）记录

### 目标
- **主后端镜像不再包含 Torch 体系**（torch/torchvision/torchaudio 等），避免数 GB 级依赖把镜像撑爆
- VAD 走 **`HOSTED_VAD_API_URL`**（你独立部署的 VAD 微服务），主后端只做业务编排

### 核心结论（针对你问的“最佳实践/断断续续音频”）
- **最佳实践**：客户端 VAD 更适合做 **turn/end detection（结束检测）** + **预滚动(pre-roll)/尾挂(hangover)**，而不是纯“静音不发帧”。  
  原因：流式 STT 的时间轴、端点检测、以及连接保活都更依赖连续音频/稳定节奏。
- **如果一定要“断断续续发音频”**：后端不会帮你“补齐成连续”，STT 也只会看到“更短的音频”。  
  你需要同时做：
  - **WebSocket 保活**（否则后端 90s inactivity 会断开）
  - **STT 侧保活**（很多 STT 在长时间无音频时会结束或降级）
  - **时间戳/分段语义**（否则 timestamps 会漂）

> 在后端 `backend/routers/transcribe.py` 里，接收数据时对 **len<=2 bytes** 的包直接当 keepalive 丢弃；你可以利用这一点做轻量保活，但这并不能替代 STT 侧的音频/保活需求。

### 变更点（已落地）
#### 1) 移除主后端对 Torch 的硬依赖
- `backend/utils/stt/vad.py`
  - 删除了本地 Silero(Torch Hub) VAD 的实现与 `import torch`
  - 保留并明确仅通过 `HOSTED_VAD_API_URL` 调用外部 VAD 服务

#### 2) Dockerfile.prod 不再安装 torch
- `backend/Dockerfile.prod`
  - 删除了 `pip install torch==...+cpu` 与 “requirements-notorch” 的逻辑
  - 直接安装 `backend/requirements.prod.txt`

#### 3) requirements.prod.txt 剪掉大体积/脚本型依赖
- `backend/requirements.prod.txt`
  - 移除了 torch 相关栈 + 其它明显不用于主后端 runtime 的大包（如 streamlit/altair/librosa/onnxruntime 等）
  - 同时移除了 `speechmatics-python`（代码路径未使用该包，但它会拉入 pyannote 相关依赖）
  - `noisereduce` 未在后端运行代码中引用（仅 requirements 中出现），因此从 prod 列表移除不影响功能

#### 4) compose 默认改用 Dockerfile.prod
- `docker-compose.yml`
  - backend service 改为 `backend/Dockerfile.prod`

### 如何验证（脚本化）
见 `backend/scripts/build_backend_prod.ps1`，它会：
- `docker compose build backend`
- 校验镜像内 **torch 不存在**
- 输出镜像大小

