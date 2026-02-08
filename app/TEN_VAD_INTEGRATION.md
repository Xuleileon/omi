## TEN VAD 集成（Flutter 主 App / Android）

### 目标
- 在 **手机麦克风录音**链路中加入 TEN VAD，实现：
  - **静音门控**（非语音不发帧）
  - **结束检测**（连续静音达到阈值后自动 stop）
  - **预滚动/尾挂**（避免截断首/尾音）

### 最佳实践（已落实到实现）
- **门控 + 结束检测** 比单纯“不发帧”更稳妥：
  - 长时间不发音频会触发 STT 超时或端点漂移
  - 用 **hangover** 保住尾音；用 **pre-roll** 保住起音
  - 结束检测触发 stop，让后端按 `conversation_timeout` 结算

### 接入位置
**手机麦克风流**（非 BLE 设备流）：
- `app/lib/providers/capture_provider.dart::streamRecording()`  
  在 `onByteReceived` 中调用 TEN VAD：
  - 语音时发送音频帧
  - 静音时不发帧（仅保留 pre-roll）
  - 连续静音超过阈值后自动 stop

### 关键实现文件
- **Dart 侧**
  - `app/lib/services/vad/ten_vad_engine.dart`  
    MethodChannel 调用 Android TEN VAD（init/process/release）
  - `app/lib/services/vad/ten_vad_gate.dart`  
    pre-roll / hangover / end-detection 决策
  - `app/lib/providers/capture_provider.dart`  
    实际接入点

- **Android 侧**
  - `app/android/app/src/main/java/com/friend/ios/tenvad/TenVad.java`  
    JNA 绑定 `libten_vad.so`
  - `app/android/app/src/main/kotlin/com/friend/ios/TenVadPlugin.kt`  
    MethodChannel 处理 `init/processPcm/release`
  - `app/android/app/src/main/jniLibs/**/libten_vad.so`  
    TEN VAD 原生库
  - `app/android/app/build.gradle`  
    添加 `jna` 依赖

### 默认参数（可调整）
- **pre-roll**: 300ms  
- **hangover**: 600ms  
- **endSilence**: 1200ms  
> 这些参数在 `TenVadGateConfig` 中统一管理。

### 注意事项
- TEN VAD 目前只接入 **手机麦克风流**；BLE 设备流（Opus/LC3）仍走原路径。
- 后端不会把“断断续续的音频”补成连续；因此 **结束检测 + 预滚动/尾挂** 是必要的。

### 运行与脚本
- 一键脚本：`app/scripts/test_ten_vad_android.ps1`
  - `prod` flavor debug 构建 + 安装 + 启动 + 拉取 logcat
- 依赖：`android/app/src/prod/google-services.json`（已从 `setup/prebuilt` 补齐）
- 若 `API_BASE_URL` 指向 `127.0.0.1`，需要 **adb reverse**：
  - `adb reverse tcp:8000 tcp:8000`

### 调试记录（首屏无法进入）
- 发现 **位置服务关闭** 时会在前台任务中抛出未捕获异常：
  - `app/lib/utils/audio/foreground.dart::_locationInBackground()`
- 处理方式：加 `try/catch`，失败仅上报错误，不再抛异常（避免阻塞首屏）。

### 调试记录（自动暂停/切碎）
- 自动停录会导致**需要手动继续**与**对话切碎**：
  - 将 “结束检测” 改为 **仅暂停发送，不停止录音**，语音恢复后自动继续发送。

### 调试记录（本地后端联调）
- 仅做 `adb reverse` 仍可能被后端立即断开：
  - 需要确保本地后端已配置 **Firebase Admin** 凭证（`SERVICE_ACCOUNT_JSON` 或 `GOOGLE_APPLICATION_CREDENTIALS`），否则 `/v4/listen` 认证失败会断开连接。
 - 中文转写变英文：
   - `backend/utils/stt/streaming.py::get_stt_service_for_language()` 之前对不支持语言回退到 `en`，已改为回退 `multi`（自动检测），并将 `zh` 视作 multi。

