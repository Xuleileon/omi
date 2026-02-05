# Flutter 编译性能优化指南

## 问题诊断

### 症状
- 首次编译时间：~10分钟
- 增量构建：仍然很慢
- 开发体验差

### 根本原因

#### 1. Debug模式启用代码混淆（最严重）
**位置**: `app/android/app/build.gradle:143-145`

```gradle
debug {
    minifyEnabled true  // ❌ 错误：debug不应该混淆
    proguardFiles ...
}
```

**影响**:
- 每次构建都进行代码混淆和资源压缩
- 构建时间增加 5-10 倍
- 调试困难（代码被混淆）

#### 2. 缺少Gradle性能优化配置
**位置**: `app/android/gradle.properties`

缺失的关键配置：
- `org.gradle.daemon=true` - Gradle守护进程
- `org.gradle.caching=true` - 构建缓存
- `org.gradle.parallel=true` - 并行编译
- `org.gradle.configuration-cache=true` - 配置缓存

#### 3. 项目特点
- 80+ 依赖包（Firebase、Intercom等重量级SDK）
- 7个 git 依赖（每次都要验证）
- 双 flavor 配置（prod/dev）

## 解决方案

### ✅ 已修复

#### 1. 禁用Debug模式的代码混淆
**文件**: `app/android/app/build.gradle`

```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        ...
    }
    debug {
        minifyEnabled false      // ✅ 修复
        shrinkResources false    // ✅ 修复
        ...
    }
}
```

#### 2. 添加Gradle性能优化
**文件**: `app/android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx5120M -XX:+UseParallelGC
android.useAndroidX=true
android.enableJetifier=true
android.enableR8=true

# Gradle performance optimizations
org.gradle.daemon=true
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configuration-cache=true
```

### 预期效果

| 场景 | 修复前 | 修复后 |
|------|--------|--------|
| 首次构建 | ~10分钟 | ~2-3分钟 |
| Hot Reload | N/A | ~1-3秒 |
| Hot Restart | N/A | ~5-10秒 |
| 增量构建 | ~8-10分钟 | ~30秒-1分钟 |

## Flutter 热更新使用指南

### 命令行方式

```bash
cd app
flutter run  # 首次启动（会较慢）

# 修改代码后，在终端按键：
r  # Hot Reload - 秒级更新，保持状态
R  # Hot Restart - 重启app，清空状态
q  # 退出
```

### IDE方式

**VS Code**:
1. F5 启动 debug
2. 修改代码后保存 (Ctrl+S)
3. 自动触发 Hot Reload

**Android Studio**:
1. Run > Debug 'app'
2. 修改代码后点击闪电图标⚡
3. 或使用快捷键 Ctrl+\ (Win) / Cmd+\ (Mac)

### 热更新类型对比

| 类型 | 速度 | 状态保持 | 适用场景 |
|------|------|---------|---------|
| **Hot Reload (r)** | 1-3秒 | ✅ 保持 | 修改UI、逻辑代码 |
| **Hot Restart (R)** | 5-10秒 | ❌ 清空 | 修改资源、初始化代码 |
| **Full Rebuild** | 2-3分钟 | ❌ 清空 | pubspec变更、原生代码改动 |

### 何时需要完全重新构建

- 修改 `pubspec.yaml` 添加/删除依赖
- 修改 Android/iOS 原生代码
- 修改 `build.gradle` 或其他配置文件
- 清理缓存后 (`flutter clean`)

## 进一步优化（可选）

### 1. 限制ABI（开发时）
在 `app/android/app/build.gradle` 的 `defaultConfig` 中添加：

```gradle
defaultConfig {
    ...
    ndk {
        abiFilters 'arm64-v8a'  // 只编译64位，开发时够用
    }
}
```

**效果**: 减少编译时间 20-30%

### 2. 开发时只使用单flavor

```bash
flutter run --flavor dev  # 只用dev flavor
```

### 3. 优化git依赖（长期）

考虑将频繁使用的git依赖：
- 固定到特定commit（避免每次验证）
- 或转为本地路径依赖（开发时）

```yaml
# 从git改为本地（开发时）
# opus_dart:
#   git:
#     url: https://github.com/mdmohsin7/opus_dart.git
#     ref: dev
opus_dart:
  path: ../local_packages/opus_dart
```

### 4. 使用profile分析

找出实际瓶颈：

```bash
cd app/android
./gradlew assembleDebug --profile --scan
```

查看生成的报告，针对性优化最慢的task。

## 验证修复

1. 清理缓存：
```bash
cd app
flutter clean
```

2. 首次构建测试：
```bash
flutter run -d <设备ID>
```

3. 测试热更新：
   - 修改任意Dart文件
   - 按 `r` 键
   - 应该在1-3秒内看到更新

## 参考资料

- [Flutter debug minifyEnabled 性能影响](https://stackoverflow.com/questions/61686511/why-is-minifyenabled-is-false-in-release-builds-by-default)
- [Flutter 2025 性能优化指南](https://medium.com/@chandru1918g/optimizing-flutter-app-performance-in-2025-a-developers-guide-c2c32e6f9f21)
- [Gradle Android构建优化](https://www.netilligence.io/blog/how-can-you-optimize-gradle-for-faster-android-builds-in-flutter/)
- [Gradle官方性能指南](https://docs.gradle.org/current/userguide/performance.html)
- [2025年Gradle构建加速技巧](https://www.droidcon.com/2025/08/15/speed-up-your-gradle-build-with-these-7-proven-tweaks-that-saved-me-hours/)

---

**最后更新**: 2026-02-05
**修复状态**: ✅ 已完成
**预期改善**: 首次构建从10分钟降至2-3分钟，支持秒级热更新
