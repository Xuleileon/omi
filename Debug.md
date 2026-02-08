# TalkFlow-Lite 调试记录

> 日期: 2026-02-08

## 1. 模拟器运行问题

### 1.1 SIGILL 崩溃（ARM 翻译不兼容）

**现象**: 应用在 Pixel_4_API_30 (x86_64) 模拟器上启动后立即崩溃

```
Fatal signal 4 (SIGILL), code -6 (SI_TKILL) in tid 9976 (mqt_v_js)
```

**根因**: Hermes JS 引擎的 JIT 编译器生成的 ARM 指令在 x86_64 模拟器的 ARM 翻译层 (libndk_translation) 下无法正确执行。API 30 的 ARM 翻译不完善，无法处理 Hermes JIT 生成的某些 ARM64 指令。

**解决方案**: 使用 `-PreactNativeArchitectures=x86_64` 构建纯 x86_64 原生 APK，避免 ARM 翻译。

```bash
cd android && ./gradlew assembleDebug -PreactNativeArchitectures=x86_64
```

**注意**: `gradle.properties` 中已设置 `reactNativeArchitectures=x86_64`，但之前被手动添加的 `ndk { abiFilters "armeabi-v7a", "arm64-v8a" }` 覆盖了。已移除该配置。

---

### 1.2 API 36 模拟器无法启动

**现象**: Pixel_6_API_36 模拟器 ADB 始终处于 `offline` 状态

```
Critical: UpdateLayeredWindowIndirect failed for ptDst=(1374, -686)
Unable to connect character device modem: Failed to connect socket: Input/output error
```

**根因**: 模拟器窗口坐标异常 (Y=-686)，导致 Windows 窗口渲染失败。即使使用 `-no-window` headless 模式也无法正常启动（ADB 仍然 offline）。

**解决方案**: 未找到可靠修复。可能需要重新创建 AVD 或更新模拟器版本。

---

### 1.3 物理设备安装失败

**现象**: 小米 MI 6 安装 APK 失败

```
INSTALL_FAILED_USER_RESTRICTED: Invalid apk
```

**根因**: 
- 设备 Android 版本 (API 28) < 应用 minSdkVersion (29)
- 小米 MIUI "通过 USB 安装" 权限限制

---

### 1.4 SoLoader DSO 加载失败（历史问题，已解决）

**现象**: 
```
SoLoaderDSONotFoundError: couldn't find DSO to load: libreactnative.so
```

**根因**: 
1. x86_64 预编译库 (TEN VAD) 与 ARM 构建混合，导致 ABI 冲突
2. `useLegacyPackaging=false` 时 SoLoader 无法从 APK 加载 ARM 库

**解决方案**: 改用 x86_64 原生构建后此问题不再存在。

---

## 2. 音频管道调试

### 2.1 录音管道验证结果

| 组件 | 状态 | 详情 |
|------|------|------|
| react-native-audio-api | ✅ 正常 | Float32Array, 1600 samples/帧, 10 帧/秒 |
| Float32 → Int16 转换 | ✅ 正常 | 正确转换 |
| TEN VAD (ONNX) | ✅ 正常 | 版本 1.0, hopSize=256, threshold=0.5 |
| VAD 帧处理 | ✅ 正常 | 每音频帧 ~6.25 VAD 帧, 批量处理 |
| 状态机 | ✅ 正常 | idle → speech_active → speech_ending → idle |
| 权限 | ✅ 正常 | RECORD_AUDIO 已授权 |
| AAudio/Oboe | ✅ 正常 | AudioFlinger 线程正常运行 |

### 2.2 模拟器麦克风限制

**现象**: 录音后没有生成任何文件，没有处理动作，前端看不到结果

**根因**: 模拟器使用主机电脑的麦克风作为音频输入。在测试环境中：
- 麦克风数据全部是环境静音 (`maxAmp ≈ 0.000214`)
- VAD 正确判断为非语音 → 状态机一直在 `idle`
- 没有语音段产生 → 不触发 STT/LLM 处理

**验证方法**: 
```
[AudioPipeline] 状态: 帧=51,  maxAmp=0.000214, state=idle, speech=0, silence=312
[AudioPipeline] 状态: 帧=101, maxAmp=0.000214, state=idle, speech=0, silence=625
[AudioPipeline] 状态: 帧=152, maxAmp=0.000214, state=idle, speech=0, silence=943
```

silence 计数器持续递增，说明 VAD 处理正常但输入全是静音。

### 2.3 端到端流程

```
Microphone → PCM Float32 (16kHz) → Int16 转换 → TEN VAD → 状态机 → (无语音) → 无输出
                                                                      → (有语音) → segment → WAV → STT → LLM → DB
```

**在模拟器上测试**: 对着电脑麦克风说话，管道会检测到语音并处理。

---

## 3. 构建配置说明

### 模拟器构建 (x86_64)

```bash
cd talkflow-lite/android
./gradlew assembleDebug -PreactNativeArchitectures=x86_64
```

### 真机构建 (ARM)

```bash
cd talkflow-lite/android
./gradlew assembleDebug -PreactNativeArchitectures=arm64-v8a
```

### 关键 Gradle 配置

- `android/gradle.properties`: `reactNativeArchitectures` 控制目标架构
- `android/app/build.gradle`: 不要手动添加 `ndk { abiFilters }`，会覆盖 Gradle 属性
- `useLegacyPackaging`: 仅在 ARM 翻译场景需要设为 `true`

---

## 4. 已知限制

1. **模拟器麦克风**: 依赖主机电脑物理麦克风，无法通过 adb 注入音频
2. **API 36 模拟器**: 在当前机器上有窗口渲染 bug，无法使用
3. **Hermes JIT**: x86_64 模拟器必须用 x86_64 原生构建，不能用 ARM 翻译
4. **小米设备**: MIUI 需要手动开启 "通过 USB 安装" 权限
