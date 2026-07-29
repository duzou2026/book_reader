import 'dart:io';

import 'package:edge_tts/edge_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'tts_service.dart';

/// 常用中文发音人（Microsoft Edge 神经语音）。
///
/// 用于朗读页发音人选择。shortName 是传给 edge_tts 的 voice 参数。
class EdgeTtsVoice {
  final String shortName;
  final String label;
  final String gender;

  const EdgeTtsVoice(this.shortName, this.label, this.gender);
}

/// 预设发音人列表（无需联网拉取全量列表，直接用这几个常用中文音色）。
const List<EdgeTtsVoice> kEdgeTtsVoices = [
  EdgeTtsVoice('zh-CN-XiaoxiaoNeural', '晓晓（女·温柔）', 'Female'),
  EdgeTtsVoice('zh-CN-YunxiNeural', '云希（男·阳光）', 'Male'),
  EdgeTtsVoice('zh-CN-XiaoyiNeural', '晓伊（女·温暖）', 'Female'),
  EdgeTtsVoice('zh-CN-YunjianNeural', '云健（男·浑厚）', 'Male'),
  EdgeTtsVoice('zh-CN-YunyangNeural', '云扬（男·播音）', 'Male'),
  EdgeTtsVoice('zh-CN-XiaohanNeural', '晓涵（女·知性）', 'Female'),
  EdgeTtsVoice('zh-CN-XiaomengNeural', '晓梦（女·活泼）', 'Female'),
  EdgeTtsVoice('zh-CN-YunfengNeural', '云枫（男·沉稳）', 'Male'),
  EdgeTtsVoice('zh-TW-HsiaoChenNeural', '曉臻（女·台湾）', 'Female'),
  EdgeTtsVoice('zh-HK-HiuMaanNeural', '曉曼（女·香港）', 'Female'),
];

/// 默认发音人。
const String kDefaultEdgeVoice = 'zh-CN-XiaoxiaoNeural';

/// 基于 Microsoft Edge 神经语音的 TTS 实现。
///
/// 通过 [edge_tts] 包连接微软免费 TTS 服务（WebSocket），合成 MP3 流后
/// 用 [just_audio] 播放。支持多发音人（见 [kEdgeTtsVoices]）和语速/音调调节。
///
/// 优点：音质远好于系统 TTS，多发音人，仿人语气。
/// 缺点：需联网（国内访问 speech.platform.bing.com 偶尔不稳定），
/// 合成有网络延迟（首次朗读需等 MP3 生成）。
class EdgeTtsService implements TtsService {
  final AudioPlayer _player = AudioPlayer();

  /// 当前发音人 shortName。
  String _voice;

  /// 合成任务，用于取消上一次未完成的合成。
  Future<void>? _synthTask;

  /// 临时 MP3 文件路径。
  File? _tempFile;

  bool _disposed = false;

  EdgeTtsService({String? voice}) : _voice = voice ?? kDefaultEdgeVoice;

  String get voice => _voice;
  set voice(String v) => _voice = v;

  @override
  TtsPlayState state = TtsPlayState.stopped;

  @override
  bool get isSpeaking => state == TtsPlayState.speaking;

  @override
  void Function(double progress)? onProgress;

  @override
  void Function()? onComplete;

  @override
  void Function(String error)? onError;

  @override
  void Function(TtsPlayState state)? onStateChanged;

  void _setState(TtsPlayState s) {
    if (_disposed) return;
    state = s;
    onStateChanged?.call(s);
  }

  /// 将 0.5-2.0 的语速转成 edge_tts 的 '+0%' 格式。
  static String _ratePercent(double rate) {
    final p = ((rate - 1.0) * 100).round();
    final sign = p >= 0 ? '+' : '';
    return '$sign${p}%';
  }

  /// 将 0.5-2.0 的音调转成 edge_tts 的 '+0Hz' 格式。
  static String _pitchHz(double pitch) {
    final h = ((pitch - 1.0) * 100).round();
    final sign = h >= 0 ? '+' : '';
    return '$sign${h}Hz';
  }

  @override
  void speak(String text, {double rate = 1.0, double pitch = 1.0}) {
    if (_disposed) return;
    // 取消上一次未完成的合成
    _synthTask?.ignore();
    stop();
    _synthTask = _speakInternal(text, rate, pitch);
  }

  Future<void> _speakInternal(String text, double rate, double pitch) async {
    _setState(TtsPlayState.speaking);
    try {
      // 1. 合成 MP3：收集所有 AudioDataEvent
      final comm = Communicate(
        text: text,
        voice: _voice,
        rate: _ratePercent(rate),
        pitch: _pitchHz(pitch),
      );
      final bytes = <int>[];
      await for (final event in comm.stream()) {
        if (event is AudioDataEvent) {
          bytes.addAll(event.data);
        }
        if (_disposed || state == TtsPlayState.stopped) return;
      }
      if (bytes.isEmpty) {
        onError?.call('朗读合成失败：未收到音频数据');
        _setState(TtsPlayState.stopped);
        return;
      }

      // 2. 写入临时文件
      final dir = await getTemporaryDirectory();
      _tempFile = File('${dir.path}/edge_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await _tempFile!.writeAsBytes(bytes, flush: true);

      if (_disposed || state == TtsPlayState.stopped) return;

      // 3. 用 just_audio 播放
      await _player.setAudioSource(AudioSource.file(_tempFile!.path));
      _player.positionStream.listen((pos) {
        final d = _player.duration?.inMilliseconds ?? 0;
        if (d > 0) onProgress?.call(pos.inMilliseconds / d);
      });
      _player.playbackEventStream.listen(
        null,
        onDone: () {
          onProgress?.call(1.0);
          onComplete?.call();
          _setState(TtsPlayState.stopped);
          _cleanupTemp();
        },
        onError: (e) {
          onError?.call('播放出错：$e');
          _setState(TtsPlayState.stopped);
        },
      );
      await _player.play();
    } catch (e) {
      if (_disposed) return;
      debugPrint('EdgeTts 合成失败: $e');
      onError?.call('朗读失败（需联网）：$e');
      _setState(TtsPlayState.stopped);
    }
  }

  @override
  void pause() {
    if (state != TtsPlayState.speaking) return;
    _player.pause();
    _setState(TtsPlayState.paused);
  }

  @override
  void resume() {
    if (state != TtsPlayState.paused) return;
    _player.play();
    _setState(TtsPlayState.speaking);
  }

  @override
  void stop() {
    _player.stop();
    _setState(TtsPlayState.stopped);
    _cleanupTemp();
  }

  void _cleanupTemp() {
    try {
      _tempFile?.deleteSync();
    } catch (_) {}
    _tempFile = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _synthTask?.ignore();
    _player.dispose();
    _cleanupTemp();
  }
}
