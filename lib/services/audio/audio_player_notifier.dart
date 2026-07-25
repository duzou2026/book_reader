import 'package:audio_session/audio_session.dart';
import 'package:book_reader/data/models/audio_chapter.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// 有声书播放状态。
class AudioPlayerState {
  final AudioChapter? currentChapter;
  final BookInfo? book;
  final List<AudioChapter> playlist;
  final int index;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final String? error;

  const AudioPlayerState({
    this.currentChapter,
    this.book,
    this.playlist = const [],
    this.index = -1,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  AudioPlayerState copyWith({
    AudioChapter? currentChapter,
    BookInfo? book,
    List<AudioChapter>? playlist,
    int? index,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    String? error,
    bool clearError = false,
  }) {
    return AudioPlayerState(
      currentChapter: currentChapter ?? this.currentChapter,
      book: book ?? this.book,
      playlist: playlist ?? this.playlist,
      index: index ?? this.index,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 有声书播放器 Notifier。
///
/// 设计：
///   - 持有当前播放列表 + 当前章节
///   - 切换章节时通过 [AudioUrlResolver] 懒加载音频 URL
///   - 配置 audio_session 以支持后台播放 / 锁屏控制
class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final AudioPlayer _player;
  final AudioUrlResolver _resolver;

  AudioPlayerNotifier(this._player, this._resolver) : super(const AudioPlayerState()) {
    _player.playerStateStream.listen((s) {
      state = state.copyWith(
        isPlaying: s.playing,
        isLoading: s.processingState == ProcessingState.loading,
      );
      if (s.processingState == ProcessingState.completed) {
        _next();
      }
    });
    _player.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _player.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });
  }

  /// 启动播放列表，从 [startIndex] 开始。
  Future<void> playList(BookInfo book, List<AudioChapter> chapters, int startIndex) async {
    state = AudioPlayerState(
      book: book,
      playlist: chapters,
      index: startIndex,
      currentChapter: startIndex < chapters.length ? chapters[startIndex] : null,
      isLoading: true,
    );
    await _configureSession();
    await _loadAt(startIndex);
  }

  Future<void> _loadAt(int index) async {
    if (index < 0 || index >= state.playlist.length) return;
    final chapter = state.playlist[index];
    state = state.copyWith(
      index: index,
      currentChapter: chapter,
      isLoading: true,
      clearError: true,
    );
    try {
      final audioUrl = await _resolver.resolve(state.book!, chapter);
      if (audioUrl.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: '无法获取音频 URL',
        );
        return;
      }
      await _player.setUrl(audioUrl);
      await _player.play();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> play() async => _player.play();
  Future<void> pause() async => _player.pause();

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> _next() async {
    if (state.index + 1 < state.playlist.length) {
      await _loadAt(state.index + 1);
    } else {
      await _player.pause();
      await _player.seek(Duration.zero);
    }
  }

  Future<void> next() async => _next();

  Future<void> previous() async {
    if (state.index > 0) {
      await _loadAt(state.index - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = const AudioPlayerState();
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    // session 设置后即生效；具体 audioSource 在 _loadAt 时设置。
  }
}

/// 音频 URL 解析器抽象。
///
/// UI 层通过此接口让播放器按需懒加载某章音频 URL，
/// 实现可指向 [GetAudioUrl] use case。
abstract class AudioUrlResolver {
  Future<String> resolve(BookInfo info, AudioChapter chapter);
}

/// 用回调函数构造的简单实现（避免 Notifier 直接持有 use case provider）。
class CallbackAudioUrlResolver implements AudioUrlResolver {
  final Future<String> Function(BookInfo, AudioChapter) _resolve;
  CallbackAudioUrlResolver(this._resolve);

  @override
  Future<String> resolve(BookInfo info, AudioChapter chapter) =>
      _resolve(info, chapter);
}
