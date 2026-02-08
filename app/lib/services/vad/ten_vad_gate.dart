import 'dart:collection';
import 'dart:typed_data';

import 'package:omi/services/vad/ten_vad_engine.dart';

class TenVadGateConfig {
  final int preRollMs;
  final int hangoverMs;
  final int endSilenceMs;
  final int sampleRate;

  const TenVadGateConfig({
    this.preRollMs = 300,
    this.hangoverMs = 600,
    this.endSilenceMs = 1200,
    this.sampleRate = 16000,
  });

  int get bytesPerMs => (sampleRate * 2) ~/ 1000;
  int get preRollBytes => preRollMs * bytesPerMs;
  int get hangoverBytes => hangoverMs * bytesPerMs;
}

class TenVadDecision {
  final List<Uint8List> sendChunks;
  final bool shouldStop;
  final bool isSpeech;
  final double probability;

  const TenVadDecision({
    required this.sendChunks,
    required this.shouldStop,
    required this.isSpeech,
    required this.probability,
  });
}

class TenVadGate {
  final TenVadEngine _engine;
  final TenVadGateConfig _config;

  final Queue<Uint8List> _preRollQueue = Queue<Uint8List>();
  int _preRollBytes = 0;

  bool _inSpeech = false;
  int _lastSpeechAtMs = 0;
  int _hangoverBytesRemaining = 0;

  TenVadGate(this._engine, {TenVadGateConfig config = const TenVadGateConfig()}) : _config = config;

  void reset() {
    _preRollQueue.clear();
    _preRollBytes = 0;
    _inSpeech = false;
    _lastSpeechAtMs = 0;
    _hangoverBytesRemaining = 0;
  }

  Future<TenVadDecision> handle(Uint8List pcmBytes) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final result = await _engine.process(pcmBytes);
    final isSpeech = result.isSpeech;

    final wasInSpeech = _inSpeech;
    if (isSpeech) {
      _inSpeech = true;
      _lastSpeechAtMs = nowMs;
      _hangoverBytesRemaining = _config.hangoverBytes;
    }

    final sendChunks = <Uint8List>[];

    if (_inSpeech) {
      // When we are in speech, pre-roll is no longer needed.
      _clearPreRoll();
    } else {
      _pushPreRoll(pcmBytes);
    }

    if (isSpeech) {
      if (!wasInSpeech) {
        sendChunks.addAll(_drainPreRoll());
      }
      sendChunks.add(pcmBytes);
    } else if (_inSpeech && _hangoverBytesRemaining > 0) {
      sendChunks.add(pcmBytes);
      _hangoverBytesRemaining -= pcmBytes.length;
      if (_hangoverBytesRemaining < 0) {
        _hangoverBytesRemaining = 0;
      }
    }

    var shouldStop = false;
    if (_inSpeech && !isSpeech) {
      final silenceMs = nowMs - _lastSpeechAtMs;
      if (silenceMs >= _config.endSilenceMs) {
        shouldStop = true;
        _inSpeech = false;
      }
    }

    return TenVadDecision(
      sendChunks: sendChunks,
      shouldStop: shouldStop,
      isSpeech: isSpeech,
      probability: result.probability,
    );
  }

  void _pushPreRoll(Uint8List chunk) {
    if (_config.preRollBytes <= 0) return;
    _preRollQueue.addLast(chunk);
    _preRollBytes += chunk.length;
    while (_preRollBytes > _config.preRollBytes && _preRollQueue.isNotEmpty) {
      final removed = _preRollQueue.removeFirst();
      _preRollBytes -= removed.length;
    }
  }

  List<Uint8List> _drainPreRoll() {
    final chunks = _preRollQueue.toList();
    _clearPreRoll();
    return chunks;
  }

  void _clearPreRoll() {
    _preRollQueue.clear();
    _preRollBytes = 0;
  }
}

