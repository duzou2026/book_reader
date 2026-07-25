/// TTS 朗读状态。
enum TtsPlayState {
  /// 已停止 / 未开始。
  stopped,

  /// 朗读中。
  speaking,

  /// 已暂停。
  paused,
}

/// TTS 朗读服务抽象接口。
///
/// 不同平台实现：
/// - Web：使用浏览器 Web Speech API（在 web_demo 中实现）
/// - 移动端：可接入 flutter_tts 包实现（预留）
///
/// 由于 TTS 强依赖平台能力，此处仅定义接口。
/// 默认实现 [NoOpTtsService] 为空操作，实际朗读由平台注入。
abstract class TtsService {
  /// 当前朗读状态。
  TtsPlayState get state;

  /// 是否正在朗读。
  bool get isSpeaking => state == TtsPlayState.speaking;

  /// 朗读进度回调（0.0-1.0）。
  void Function(double progress)? onProgress;

  /// 朗读完成回调。
  void Function()? onComplete;

  /// 朗读出错回调。
  void Function(String error)? onError;

  /// 状态变化回调。
  void Function(TtsPlayState state)? onStateChanged;

  /// 开始朗读。
  ///
  /// [text] 待朗读文本，[rate] 语速 0.5-2.0，[pitch] 音调 0.5-2.0。
  void speak(String text, {double rate = 1.0, double pitch = 1.0});

  /// 暂停朗读。
  void pause();

  /// 恢复朗读。
  void resume();

  /// 停止朗读。
  void stop();

  /// 释放资源。
  void dispose();
}

/// 空操作实现：不支持 TTS 的平台上使用。
class NoOpTtsService implements TtsService {
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

  @override
  void speak(String text, {double rate = 1.0, double pitch = 1.0}) {
    onError?.call('当前平台不支持 TTS 朗读');
  }

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void stop() {}

  @override
  void dispose() {}
}
