# Flutter 2026 最佳实践深度研究

> 基于2026年2月的深度调研，涵盖技术栈、工具链、架构模式和实战经验

---

## 🔥 2026年核心技术更新

### 1. Flutter 3.27+ 与 Impeller 渲染引擎

**重大变化**：Impeller已成为iOS和Android API 29+的默认渲染引擎，完全替代Skia。

**关键优势**：
- **帧光栅化速度提升50%**
- **120 FPS稳定支持**（高刷新率设备）
- **帧丢失率从12%降至1.5%**
- **消除shader编译导致的"jank"**（使用AOT编译）
- **GPU直接通信**（Metal/Vulkan/Direct3D）

**权衡**：
- Vulkan模式下功耗可能增加~15%
- 需要在性能和电池续航之间平衡

**参考资料**：
- [Skia vs Impeller: 120 FPS之战](https://medium.com/@serikbay.a04/skia-vs-impeller-the-battle-for-120-fps-58cc23418c1d)
- [Flutter准备挑战原生性能](https://blog.stackademic.com/why-flutter-is-ready-to-challenge-native-performance-863aea32cc57)
- [掌握Impeller渲染器](https://vibe-studio.ai/insights/mastering-flutter-s-impeller-renderer-for-high-performance-graphics)

### 2. Dart 3.7 与语言特性演进

**Dart Macros被放弃**：
- Dart团队已停止通用宏（macros）的开发
- 转向**Augmentations**功能（独立于宏的增强特性）
- 改进build_runner性能

**Dart 3.x新特性**（可立即使用）：
- **Sealed Classes + Pattern Matching**：可替代freezed的部分功能
- **Records + Destructuring**：减少样板代码
- **增强的Type Inference**
- **Context Parameters**（Kotlin 2.2引入）

**迁移建议**：
- 评估是否可以用sealed classes替代部分freezed用法
- 使用records返回多值，减少创建小类
- 利用pattern matching简化复杂的if-else

**参考资料**：
- [Dart Macros更新：数据序列化](https://blog.dart.dev/an-update-on-dart-macros-data-serialization-06d3037d4f12)
- [如何替代Freezed](https://leancode.co/blog/how-to-replace-freezed-in-dart)
- [Flutter代码生成：Freezed + build_runner](https://dasroot.net/posts/2026/01/flutter-code-generation-freezed-json-serializable-build-runner/)

---

## 🛠️ 2026年工具链革新

### 1. Shorebird Code Push - OTA更新革命

**你的项目已集成**（`app/shorebird.yaml`），但可能未充分利用。

**核心价值**：
- **绕过应用商店审核**，即时推送更新
- **零停机时间修复critical bug**
- 用户无感知更新体验

**当前配置**：
```yaml
app_id: cf8e9392-a0cd-4d49-a5a2-38ef857d4586
flavors:
  dev: cf8e9392-a0cd-4d49-a5a2-38ef857d4586
  prod: 2251eb7e-ac1b-44af-a732-be172d69f072
# auto_update: true (默认启用)
```

**优化建议**：
```bash
# 使用Shorebird发布而非flutter build
shorebird release android --flavor prod
shorebird patch android --flavor prod  # 推送补丁
```

**参考资料**：
- [Shorebird官网](https://shorebird.dev/)
- [Flutter静默更新指南](https://www.freecodecamp.org/news/how-to-push-silent-updates-in-flutter-using-shorebird/)
- [Shorebird Code Push包](https://pub.dev/packages/shorebird_code_push)

### 2. Gradle 8.x + Kotlin DSL

**重大变化**：Gradle 8.0+默认使用Kotlin DSL，不再推荐Groovy DSL。

**你的项目**：仍在使用Groovy DSL（`build.gradle`）

**迁移收益**：
- 强类型检查
- IDE自动完成更好
- 可读性提升
- 与Kotlin项目语言栈统一

**迁移步骤**：
```bash
# 重命名 build.gradle -> build.gradle.kts
# 语法从 Groovy 迁移到 Kotlin
```

**参考资料**：
- [Android 2026开发最佳实���](https://medium.com/@androidlab/android-development-in-2026-tools-libraries-and-predictions-cb6981c6d084)

### 3. Melos + FVM - Monorepo管理

**你的项目结构**：app + backend，天然适合monorepo。

**Melos功能**：
- 跨多个package运行命令
- 统一版本管理和changelog
- CI/CD集成
- 原子化发布

**FVM功能**：
- 管理多个Flutter SDK版本
- 确保团队统一SDK版本
- 自动更新Melos的sdkPath配置

**实施方案**：
```yaml
# melos.yaml
name: omi_workspace
packages:
  - app
  - backend  # 如果转为Dart package
scripts:
  analyze: melos exec -- flutter analyze
  test: melos exec -- flutter test
  format: melos exec -- dart format .
```

**参考资料**：
- [Melos完全指南](https://tiwariashuism.medium.com/mastering-melos-the-ultimate-guide-to-flutter-monorepo-management-for-senior-developers-032198742c9b)
- [FVM Monorepo配置](https://fvm.app/documentation/guides/monorepo)
- [Flutter Monorepo实践](https://blog.codemagic.io/flutter-monorepos/)

### 4. 开发效率工具

#### Zapp.run - 在线Flutter沙盒
- 浏览器直接运行Flutter
- 嵌入文档/博客
- 快速原型验证

#### Widgetbook - Flutter的Storybook
- 组件隔离开发
- UI组件预览和测试
- 动态参数调整
- 设计系统文档化

**推荐VS Code扩��**：
```json
{
  "recommendations": [
    "Dart-Code.flutter",
    "Dart-Code.dart-code",
    "robert-brunhage.flutter-riverpod-snippets",
    "usernamehw.errorlens",
    "jeroen-meijer.pubspec-assist",
    "BendixMa.dart-data-class-generator"
  ]
}
```

**参考资料**：
- [Zapp.run官网](https://zapp.run/)
- [Widgetbook官网](https://www.widgetbook.io/)
- [Flutter组件迁移到Widgetbook](https://leancode.co/blog/moving-flutter-widgets-to-widgetbook)

---

## 🏗️ 2026年架构模式演进

### Feature-First Clean Architecture (FFCA)

**2026年推荐架构**：结合Clean Architecture和Feature-First原则。

**核心理念**：
- 每个feature独立的Clean Architecture层
- 垂直切片架构
- 高内聚、低耦合

**目录结构示例**：
```
lib/
├── features/
│   ├── auth/
│   │   ├── data/           # API、仓储、DTO
│   │   ├── domain/         # 实体、用例
│   │   └── presentation/   # UI、状态管理
│   ├── memories/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── chat/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── core/
│   ├── network/
│   ├── storage/
│   └── utils/
└── shared/
    ├── widgets/
    └── theme/
```

**你的项目评估**：
- 当前似乎是扁平化结构（`lib/pages/`, `lib/services/`）
- 建议逐步迁移到feature-first

**迁移策略**：
1. 新功能使用FFCA
2. 逐步重构旧代码
3. 使用Melos管理feature依赖

**参考资料**：
- [Feature-First Clean Architecture](https://medium.com/@remy.baudet/feature-first-clean-architecture-for-flutter-246366e71c18)
- [MVVM vs Clean Architecture](https://medium.com/@shubhasachan/flutter-app-architecture-mvvm-vs-clean-architecture-75cc21faf288)
- [Flutter架构指南](https://docs.flutter.dev/app-architecture/guide)

---

## 🔐 2026年安全最佳实践

### 核心安全措施

#### 1. 数据加密
```dart
// 使用 flutter_secure_storage (AES-256)
final storage = FlutterSecureStorage();
await storage.write(key: 'api_token', value: token);
```

#### 2. 生物识别认证
```dart
// 使用 local_auth 或 biometricx
final auth = LocalAuthentication();
final didAuthenticate = await auth.authenticate(
  localizedReason: 'Please authenticate',
  options: const AuthenticationOptions(
    biometricOnly: true,
    useErrorDialogs: true,
  ),
);
```

#### 3. OAuth 2.0最佳实践
- **短令牌 + 长刷新���牌**
- **刷新令牌用生物识别保护**
- **PKCE扩展**

#### 4. SSL Pinning
```dart
// 防止中间人攻击
SecurityContext context = SecurityContext();
context.setTrustedCertificates('assets/ca.pem');
```

#### 5. 代码混淆
```bash
# Android release已启用（build.gradle:135 minifyEnabled true）
# iOS需要在Xcode配置
flutter build ios --obfuscate --split-debug-info=./debug-info
```

#### 6. OWASP Mobile Top 10合规
- 输入验证
- 安全错误处理
- 移除debug日志
- API密钥不硬编码

**参考资料**：
- [Flutter安全2026指南](https://medium.com/@mr.vijaysharma96/how-to-secure-your-flutter-app-in-2025-with-owasp-libraries-code-examples-86a8904a9f28)
- [Flutter应用安全保障](https://digitalfractal.com/ensuring-mobile-application-security-in-flutter-development/)
- [保护Flutter应用](https://8ksec.io/securing-flutter-applications/)

---

## ⚡ 2026年性能优化实战

### 1. 构建优化（已修复）
参见 `flutter-build-optimization.md`

### 2. Runtime性能优化

#### Widget优化
```dart
// ✅ 使用const构造函数
const Text('Hello');

// ✅ 拆分大Widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(),
        _Body(),
        _Footer(),
      ],
    );
  }
}

// ❌ 避免在build中创建对象
Widget build(BuildContext context) {
  final controller = TextEditingController(); // 错误！每次rebuild都创建
}
```

#### CPU密集任务使用Isolates
```dart
import 'dart:isolate';

Future<void> heavyComputation() async {
  final result = await Isolate.run(() {
    // 复杂计算，不阻塞UI线程
    return processLargeData();
  });
}
```

#### 图片优化
```dart
// 使用cached_network_image（项目已集成）
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  maxWidthDiskCache: 1000, // 限制缓存大小
);

// 使用svg替代png（减小包大小）
SvgPicture.asset('assets/icon.svg');
```

#### 列表优化
```dart
// 使用ListView.builder而非ListView
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ItemWidget(items[index]);
  },
);

// 长列表使用AutomaticKeepAliveClientMixin保持状态
```

### 3. 性能监控

**Flutter DevTools**：
- Widget Inspector：检查widget树
- Performance：帧率分析
- Memory：内存泄漏检测

**Firebase Performance Monitoring**（项目已集成）：
```dart
final trace = FirebasePerformance.instance.newTrace('api_call');
await trace.start();
// ... API调用
await trace.stop();
```

**Sentry**（推荐添加）：
```yaml
dependencies:
  sentry_flutter: ^7.0.0
```

**参考资料**：
- [Flutter性能监控工具](https://embrace.io/blog/top-flutter-monitoring-tools/)
- [Firebase Crashlytics监控](https://technorizen.com/using-firebase-crashlytics-to-monitor-flutter-app-performance/)

---

## 🎯 状态管理2026

### Riverpod 3.0 - 首选方案

**为什么选Riverpod**：
- 编译时安全
- @riverpod宏减少样板代码
- 内置离线持久化
- 最适合Clean Architecture

**你的项目**：使用Provider（较老旧）

**迁移路径**：
```dart
// Provider (旧)
class CounterNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  void increment() {
    _count++;
    notifyListeners();
  }
}

// Riverpod 3.0 (新)
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}

// 使用
ref.watch(counterProvider);
ref.read(counterProvider.notifier).increment();
```

### BLoC 9.0 - 企业级选择

**适用场景**：
- 大型团队
- 严格审计要求
- 复杂状态流转

**优势**：
- DevTools支持改进
- 简化事件语法
- 自动生成unions

### Signals - 性能关键场景

**适用场景**：
- 局部UI状态
- MVP快速开发
- 需要精细UI更新

**限制**：
- 异步支持有限
- 生态系统尚不成熟

**参考资料**：
- [2025状态管理对比](https://nurobyte.medium.com/flutter-state-management-in-2025-riverpod-vs-bloc-vs-signals-8569cbbef26f)
- [最佳状态管理库](https://foresightmobile.com/blog/best-flutter-state-management)
- [Riverpod vs BLoC vs Signals](https://www.creolestudios.com/flutter-state-management-tool-comparison/)

---

## 🧪 2026年测试策略

### Patrol - 超越integration_test

**优势**：
- 测试原生权限对话框
- 测试WebView
- 更直观的API

```dart
patrolTest('登录流程', ($) async {
  await $.pumpWidgetAndSettle(MyApp());

  // 点击登录按钮
  await $(#loginButton).tap();

  // 处理原生权限弹窗（integration_test做不到）
  await $.native.grantPermissionWhenInUse();

  // 验证结果
  expect($(#homeScreen), findsOneWidget);
});
```

### Golden Testing - 视觉回归测试

**golden_screenshot包**：
```dart
testGoldens('按钮样式测试', (tester) async {
  await tester.pumpWidgetBuilder(
    MyButton(text: 'Submit'),
    wrapper: materialAppWrapper(),
    surfaceSize: Size(400, 200),
  );

  await screenMatchesGolden(tester, 'button_default');
});
```

**自动生成应用商店截图**：
```dart
// 多设备、多语言截图自动化
final configs = [
  DeviceConfig.iPhone13ProMax(),
  DeviceConfig.pixel6(),
];

for (final config in configs) {
  await generateScreenshot(config, locale: 'zh_CN');
}
```

**参考资料**：
- [Patrol集成测试](https://www.telusdigital.com/insights/digital-experience/article/patrol-integration-testing-accelerating-flutter-app-development)
- [Golden Screenshot包](https://pub.dev/packages/golden_screenshot)

---

## 🚀 CI/CD 2026最佳实践

### GitHub Actions + Fastlane

**你的项目**：可能已有`.github/workflows`

**推荐配置**：
```yaml
# .github/workflows/flutter_ci.yml
name: Flutter CI

on:
  pull_request:
  push:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.3'
          cache: true  # 缓存Flutter SDK

      - name: Get dependencies
        run: flutter pub get
        working-directory: app

      - name: Analyze
        run: flutter analyze
        working-directory: app

      - name: Run tests
        run: flutter test
        working-directory: app

      - name: Build APK
        run: flutter build apk --flavor dev
        working-directory: app

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy with Shorebird
        run: |
          shorebird patch android --flavor prod
```

**Fastlane配置**：
```ruby
# android/fastlane/Fastfile
lane :beta do
  gradle(task: "clean assembleRelease")
  upload_to_play_store(
    track: 'beta',
    skip_upload_metadata: true,
  )
end
```

**性能优化技巧**：
- 缓存Flutter SDK和pub dependencies
- 并行运行测试和构建
- 使用矩阵策略测试多版本
- 语义化版本标签（v1.0.0）

**参考资料**：
- [10个CI/CD管道减少85%发布时间](https://medium.com/@alaxhenry0121/10-flutter-ci-cd-pipelines-that-reduced-our-release-time-by-85-21afadad1722)
- [GitHub Actions + Fastlane自动化](https://vibe-studio.ai/insights/automating-flutter-ci-cd-pipelines-with-github-actions-and-fastlane)
- [Codemagic CI/CD](https://blog.codemagic.io/ci-cd-for-flutter-with-fastlane-codemagic/)

---

## 📦 依赖管理优化

### 你的项目问题

**Git依赖过多**（7个）：
```yaml
mixpanel_flutter:
  git: https://github.com/beastoin/mixpanel-flutter.git
opus_dart:
  git: https://github.com/mdmohsin7/opus_dart.git
# ... 还有5个
```

**问题**：
- 每次pub get都要验证git仓库
- 增加构建时间
- 网络依赖高

**优化方案**：

#### 1. 固定commit hash
```yaml
opus_dart:
  git:
    url: https://github.com/mdmohsin7/opus_dart.git
    ref: a1b2c3d4  # 固定commit，避免每次验证
```

#### 2. 本地path依赖（开发时）
```yaml
opus_dart:
  path: ../local_packages/opus_dart  # 开发时使用
```

#### 3. 发布到私有pub仓库
- 考虑使用Dart pub私有仓库
- 或cloudsmith.io、JFrog Artifactory

### 依赖审计

**自动化依赖许可验证**：
```bash
flutter pub deps --style=compact
flutter pub outdated  # 检查过期依赖
```

**定期更新**：
```yaml
# 使用dependabot或renovate自动PR
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/app"
    schedule:
      interval: "weekly"
```

---

## 📱 你的项目具体改进建议

基于代码审查，这里是针对Omi项目的具体优化：

### 🚨 立即执行（High Priority）

#### 1. ✅ 已修复：Gradle构建优化
- 禁用debug模式的minifyEnabled
- 添加Gradle性能配置

#### 2. 充分利用Shorebird
```bash
# 设置CI/CD自动化推送补丁
shorebird patch android --flavor prod --release-version 1.0.522+661
```

#### 3. 升级Flutter到最新稳定版
```bash
# 当前：Flutter 3.29.3 (2025-04)
# 建议：升级到3.30+以获得Impeller改进
flutter upgrade
```

### 🔄 中期迁移（Medium Priority）

#### 4. 状态管理迁移：Provider → Riverpod 3.0
```dart
// 创建迁移计划
1. 新feature使用Riverpod
2. 渐进式重构老代码
3. 最终移除Provider依赖
```

#### 5. 架构重构：扁平化 → Feature-First
```
lib/
├── features/
│   ├── memories/
│   ├── chat/
│   ├── settings/
│   └── home/
└── core/
```

#### 6. 依赖管理优化
```yaml
# 将git依赖固定到commit hash
# 评估是否可以用pub.dev替代品
```

### 🌟 长期优化（Low Priority）

#### 7. Monorepo重构（Melos + FVM）
```yaml
# melos.yaml
packages:
  - app
  - packages/*  # 拆分共享package
```

#### 8. 测试覆盖率提升
```bash
# 当前测试：app/test.sh
# 目标：添加Patrol集成测试、Golden测试
```

#### 9. CI/CD优化
```yaml
# 添加：
- 自动化测试
- 代码覆盖率检查
- 性能基准测试
- Shorebird自动发布
```

#### 10. 性能监��集成
```yaml
dependencies:
  sentry_flutter: ^7.0.0  # 添加错误追踪
  # Firebase Performance已集成
```

---

## 🎓 学习资源

### 官方文档
- [Flutter官方架构指南](https://docs.flutter.dev/app-architecture/guide)
- [Dart语言特性](https://dart.dev/language)
- [Gradle性能优化](https://docs.gradle.org/current/userguide/performance.html)

### 社区资源
- [Flutter 2026趋势](https://www.siddhiinfosoft.com/blog/flutter-in-2026-trends-services-opportunities/)
- [Dart 3.x新特性](https://3ftechnolabs.com/blog/flutter-dart-2026-features-every-developer-should-know)
- [2026移动开发实用指南](https://www.softwareco.com/mobile-app-development-best-practices-a-practical-guide-for-2026/)

### YouTube频道
- Flutter官方频道
- Reso Coder（Clean Architecture）
- Code With Andrea（测试与架构）

---

## 📊 实施优先级矩阵

| 任务 | 影响 | 难度 | 优先级 |
|------|------|------|--------|
| Gradle构建优化 | ⭐⭐⭐⭐⭐ | ⭐ | ✅ 已完成 |
| Shorebird自动化 | ⭐⭐⭐⭐⭐ | ⭐⭐ | 🚨 High |
| Flutter升级到3.30+ | ⭐⭐⭐⭐ | ⭐ | 🚨 High |
| Provider→Riverpod | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 🔄 Medium |
| Feature-First重构 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 🔄 Medium |
| 依赖管理优化 | ⭐⭐⭐ | ⭐⭐ | 🔄 Medium |
| Melos Monorepo | ⭐⭐⭐ | ⭐⭐⭐ | 🌟 Low |
| Patrol测试 | ⭐⭐⭐ | ⭐⭐⭐ | 🌟 Low |
| CI/CD完善 | ⭐⭐⭐⭐ | ⭐⭐⭐ | 🌟 Low |
| Sentry集成 | ⭐⭐⭐ | ⭐ | 🌟 Low |

---

## 🔗 所有参考资料汇总

### Flutter性能与核心技术
1. [Flutter 2026趋势与服务](https://www.siddhiinfosoft.com/blog/flutter-in-2026-trends-services-opportunities/)
2. [Dart 2026特性](https://3ftechnolabs.com/blog/flutter-dart-2026-features-every-developer-should-know)
3. [7个Flutter重大变化](https://medium.com/@sharma-deepak/7-major-flutter-changes-as-we-head-into-2026-ad7153625cac)
4. [Impeller vs Skia: 120FPS之战](https://medium.com/@serikbay.a04/skia-vs-impeller-the-battle-for-120-fps-58cc23418c1d)
5. [Flutter挑战原生性能](https://blog.stackademic.com/why-flutter-is-ready-to-challenge-native-performance-863aea32cc57)

### Android与Gradle
6. [Android 2026最佳实践](https://medium.com/@androidlab/android-development-in-2026-tools-libraries-and-predictions-cb6981c6d084)
7. [Gradle最佳实践](https://docs.gradle.org/current/userguide/best_practices_general.html)
8. [Gradle优化指南](https://www.netilligence.io/blog/how-can-you-optimize-gradle-for-faster-android-builds-in-flutter/)

### Shorebird Code Push
9. [Shorebird官网](https://shorebird.dev/)
10. [Flutter��默更新](https://www.freecodecamp.org/news/how-to-push-silent-updates-in-flutter-using-shorebird/)

### Monorepo与工具链
11. [Melos完全指南](https://tiwariashuism.medium.com/mastering-melos-the-ultimate-guide-to-flutter-monorepo-management-for-senior-developers-032198742c9b)
12. [FVM Monorepo](https://fvm.app/documentation/guides/monorepo)
13. [Flutter Monorepo实践](https://blog.codemagic.io/flutter-monorepos/)

### CI/CD
14. [GitHub Actions + Fastlane](https://vibe-studio.ai/insights/automating-flutter-ci-cd-pipelines-with-github-actions-and-fastlane)
15. [10个CI/CD管道](https://medium.com/@alaxhenry0121/10-flutter-ci-cd-pipelines-that-reduced-our-release-time-by-85-21afadad1722)

### 测试
16. [Patrol集成测试](https://www.telusdigital.com/insights/digital-experience/article/patrol-integration-testing-accelerating-flutter-app-development)
17. [Golden Screenshot](https://pub.dev/packages/golden_screenshot)

### 状态管理
18. [2025状态管理对比](https://nurobyte.medium.com/flutter-state-management-in-2025-riverpod-vs-bloc-vs-signals-8569cbbef26f)
19. [最佳状态管理](https://foresightmobile.com/blog/best-flutter-state-management)

### 性能监控
20. [Flutter监控工具](https://embrace.io/blog/top-flutter-monitoring-tools/)
21. [Firebase Crashlytics](https://technorizen.com/using-firebase-crashlytics-to-monitor-flutter-app-performance/)

### 安全
22. [Flutter安全2026](https://medium.com/@mr.vijaysharma96/how-to-secure-your-flutter-app-in-2025-with-owasp-libraries-code-examples-86a8904a9f28)
23. [保护Flutter应用](https://8ksec.io/securing-flutter-applications/)

### 架构
24. [Feature-First Clean Architecture](https://medium.com/@remy.baudet/feature-first-clean-architecture-for-flutter-246366e71c18)
25. [MVVM vs Clean Architecture](https://medium.com/@shubhasachan/flutter-app-architecture-mvvm-vs-clean-architecture-75cc21faf288)

### 开发工具
26. [Widgetbook官网](https://www.widgetbook.io/)
27. [Zapp.run](https://zapp.run/)

### Dart语言特性
28. [Dart Macros更新](https://blog.dart.dev/an-update-on-dart-macros-data-serialization-06d3037d4f12)
29. [替代Freezed](https://leancode.co/blog/how-to-replace-freezed-in-dart)

### 依赖注入与导航
30. [get_it + injectable + GoRouter](https://www.dhiwise.com/post/exploring-flutter-tools-getit-injectable-and-autoroute)

---

**文档更新时间**：2026-02-05
**研究深度**：30+资料来源
**适用项目**：Omi (app + backend)
