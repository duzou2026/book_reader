import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// 基于 flutter_tts 插件的 TTS 实现。
///
/// 支持 Android / iOS。Web 平台不支持，调用方应自行回退到 [NoOpTtsService]
/// 或浏览器 Web Speech API。
class FlutterTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  TtsPlayState _state = TtsPlayState.stopped;

  /// 当前朗读的完整文本，用于 resume 时重新启动。
  String _currentText = '';
  double _currentRate = 1.0;
  double _currentPitch = 1.0;

  FlutterTtsService() {
    _setupHandlers();
    _init();
  }

  Future<void> _init() async {
    try {
      // 中文优先；系统无中文时由 flutter_tts 自动回退到默认语言
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(_normalizeRate(1.0));
      await _tts.setPitch(1.0);
    } catch (_) {
      // 初始化失败不抛，speak 时会触发 onError
    }
  }

  void _setupHandlers() {
    _tts.setStartHandler(() {
      _setState(TtsPlayState.speaking);
    });

    _tts.setCompletionHandler(() {
      _currentText = '';
      _setState(TtsPlayState.stopped);
      onComplete?.call();
    });

    _tts.setCancelHandler(() {
      _currentText = '';
      _setState(TtsPlayState.stopped);
    });

    _tts.setErrorHandler((msg) {
      _setState(TtsPlayState.stopped);
      onError?.call(msg);
    });

    _tts.setProgressHandler(
      (text, start, end, word) {
        // 进度回调：归一化为 0.0-1.0
        if (text.isNotEmpty && end > 0) {
          final progress = (end / text.length).clamp(0.0, 1.0);
          onProgress?.call(progress);
        }
      },
    );
  }

  @override
  TtsPlayState get state => _state;

  @override
  bool get isSpeaking => _state == TtsPlayState.speaking;

  @override
  void Function(double progress)? onProgress;

  @override
  void Function()? onComplete;

  @override
  void Function(String error)? onError;

  @override
  void Function(TtsPlayState state)? onStateChanged;

  @override
  void speak(String text, {double rate = 1.0, double pitch = 1.0}) {
    if (kIsWeb) {
      onError?.call('Web 平台不支持 flutter_tts，请使用浏览器朗读');
      return;
    }
    if (text.isEmpty) {
      onComplete?.call();
      return;
    }

    _currentText = text;
    _currentRate = rate;
    _currentPitch = pitch;

    Future<void> () async {
      try {
        await _tts.stop();
        await _tts.setSpeechRate(_normalizeRate(rate));
        await _tts.setPitch(pitch);
        final result = await _tts.speak(text);
        if (result != 1) {
          _setState(TtsPlayState.stopped);
          onError?.call('朗读启动失败');
        }
      } catch (e) {
        _setState(TtsPlayState.stopped);
        onError?.call('朗读异常: $e');
      }
    }();
  }

  @override
  void pause() {
    if (_state != TtsPlayState.speaking) return;
    Future<void> () async {
      try {
        await _tts.pause();
        _setState(TtsPlayState.paused);
      } catch (_) {}
    }();
  }

  @override
  void resume() {
    if (_state != TtsPlayState.paused) return;
    // flutter_tts 的 pause/resume 在 Android 上是暂停/继续同一段，
    // 但在 iOS 上 pause 后无法 resume，需要重新 speak。
    // 这里用 _currentText 重新启动以兼容两端。
    if (_currentText.isNotEmpty) {
      speak(_currentText, rate: _currentRate, pitch: _currentPitch);
    }
  }

  @override
  void stop() {
    Future<void> () async {
      try {
        await _tts.stop();
      } catch (_) {}
      _currentText = '';
      _setState(TtsPlayState.stopped);
    }();
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
  }

  void _setState(TtsPlayState s) {
    if (_state == s) return;
    _state = s;
    onStateChanged?.call(s);
  }

  /// 把应用层 0.5-2.0 的语速映射到 flutter_tts 的 0.0-1.0 范围。
  ///
  /// flutter_tts Android: 0.0 最慢，1.0 最快；iOS: 0.0-1.0 同样。
  /// 应用层 1.0 = 正常语速 → flutter_tts 0.5
  /// 应用层 0.5 = 慢 → flutter_tts 0.25
  /// 应用层 2.0 = 快 → flutter_tts 1.0
  double _normalizeRate(double rate) {
    return (rate * 0.5).clamp(0.0, 1.0);
  }
}
