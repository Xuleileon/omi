import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:omi/utils/platform/platform_service.dart';

class TenVadResult {
  final bool isSpeech;
  final double probability;

  const TenVadResult({required this.isSpeech, required this.probability});
}

class TenVadEngine {
  static const MethodChannel _channel = MethodChannel('com.friend.ios/ten_vad');

  bool _initialized = false;

  Future<void> init({int hopSize = 256, double threshold = 0.5}) async {
    if (!PlatformService.isAndroid) return;
    if (_initialized) return;
    await _channel.invokeMethod('init', {
      'hopSize': hopSize,
      'threshold': threshold,
    });
    _initialized = true;
  }

  Future<TenVadResult> process(Uint8List pcmBytes) async {
    if (!PlatformService.isAndroid || !_initialized) {
      return const TenVadResult(isSpeech: true, probability: 1.0);
    }
    final Map<dynamic, dynamic> result = await _channel.invokeMethod('processPcm', {
      'pcm': pcmBytes,
    });
    return TenVadResult(
      isSpeech: result['speech'] == true,
      probability: (result['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<void> dispose() async {
    if (!PlatformService.isAndroid || !_initialized) return;
    await _channel.invokeMethod('release');
    _initialized = false;
  }
}

