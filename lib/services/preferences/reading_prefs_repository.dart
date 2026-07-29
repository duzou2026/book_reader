import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 全局阅读偏好（所有书共享）。
class ReadingPrefs {
  /// 字号（12-32）。
  final double fontSize;

  /// 行距（1.2-2.4）。
  final double lineHeight;

  /// 背景主题索引（0=白色 / 1=护眼米黄 / 2=夜间）。
  final int backgroundIndex;

  /// 翻页方式。
  final PageMode pageMode;

  /// 是否跟随系统主题（夜间模式）。
  final bool followSystemDark;

  /// 字体索引（0=系统默认 / 1=衬线 / 2=无衬线 / 3=等宽）。
  final int fontFamilyIndex;

  /// 屏幕亮度（0.0-1.0），null 表示跟随系统。
  final double? brightness;

  /// 自动阅读速度（每分钟滚动行数，0=关闭）。
  final int autoReadSpeed;

  /// TTS 语速（0.5-2.0）。
  final double ttsRate;

  /// TTS 音调（0.5-2.0）。
  final double ttsPitch;

  /// TTS 发音人 shortName（edge_tts，默认晓晓）。
  final String ttsVoice;

  /// 是否繁体显示。
  final bool traditionalChinese;

  const ReadingPrefs({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.backgroundIndex = 0,
    this.pageMode = PageMode.scroll,
    this.followSystemDark = false,
    this.fontFamilyIndex = 0,
    this.brightness,
    this.autoReadSpeed = 0,
    this.ttsRate = 1.0,
    this.ttsPitch = 1.0,
    this.ttsVoice = 'zh-CN-XiaoxiaoNeural',
    this.traditionalChinese = false,
  });

  bool get autoReadEnabled => autoReadSpeed > 0;

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'backgroundIndex': backgroundIndex,
        'pageMode': pageMode.name,
        'followSystemDark': followSystemDark,
        'fontFamilyIndex': fontFamilyIndex,
        'brightness': brightness,
        'autoReadSpeed': autoReadSpeed,
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'ttsVoice': ttsVoice,
        'traditionalChinese': traditionalChinese,
      };

  factory ReadingPrefs.fromJson(Map<String, dynamic> json) {
    return ReadingPrefs(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.7,
      backgroundIndex: json['backgroundIndex'] as int? ?? 0,
      pageMode: PageMode.values.firstWhere(
        (m) => m.name == json['pageMode'],
        orElse: () => PageMode.scroll,
      ),
      followSystemDark: json['followSystemDark'] as bool? ?? false,
      fontFamilyIndex: json['fontFamilyIndex'] as int? ?? 0,
      brightness: (json['brightness'] as num?)?.toDouble(),
      autoReadSpeed: json['autoReadSpeed'] as int? ?? 0,
      ttsRate: (json['ttsRate'] as num?)?.toDouble() ?? 1.0,
      ttsPitch: (json['ttsPitch'] as num?)?.toDouble() ?? 1.0,
      ttsVoice: json['ttsVoice'] as String? ?? 'zh-CN-XiaoxiaoNeural',
      traditionalChinese: json['traditionalChinese'] as bool? ?? false,
    );
  }

  ReadingPrefs copyWith({
    double? fontSize,
    double? lineHeight,
    int? backgroundIndex,
    PageMode? pageMode,
    bool? followSystemDark,
    int? fontFamilyIndex,
    Object? brightness,
    int? autoReadSpeed,
    double? ttsRate,
    double? ttsPitch,
    String? ttsVoice,
    bool? traditionalChinese,
  }) {
    return ReadingPrefs(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      backgroundIndex: backgroundIndex ?? this.backgroundIndex,
      pageMode: pageMode ?? this.pageMode,
      followSystemDark: followSystemDark ?? this.followSystemDark,
      fontFamilyIndex: fontFamilyIndex ?? this.fontFamilyIndex,
      brightness: brightness == null
          ? this.brightness
          : (brightness is double ? brightness : null),
      autoReadSpeed: autoReadSpeed ?? this.autoReadSpeed,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      traditionalChinese: traditionalChinese ?? this.traditionalChinese,
    );
  }
}

/// 翻页方式。
enum PageMode {
  /// 上下滚动。
  scroll,
  /// 左右滑动翻页。
  horizontal,
  /// 仿真翻页。
  simulation,
}

/// 阅读偏好 Hive 仓储。
///
/// Box: `'reading_prefs'`，单 key `'global'` 存全局偏好。
class ReadingPrefsRepository {
  final Box<String> _box;
  ReadingPrefsRepository(this._box);

  static const String boxName = 'reading_prefs';
  static const String _key = 'global';

  Future<ReadingPrefs> get() async {
    final raw = _box.get(_key);
    if (raw == null) return const ReadingPrefs();
    return ReadingPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ReadingPrefs prefs) async {
    await _box.put(_key, jsonEncode(prefs.toJson()));
  }
}

/// 响应式的全局阅读偏好 Notifier。
class ReadingPrefsNotifier extends StateNotifier<ReadingPrefs> {
  final ReadingPrefsRepository _repo;

  ReadingPrefsNotifier(this._repo) : super(const ReadingPrefs()) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.get();
  }

  Future<void> setFontSize(double v) async {
    state = state.copyWith(fontSize: v);
    await _repo.save(state);
  }

  Future<void> setLineHeight(double v) async {
    state = state.copyWith(lineHeight: v);
    await _repo.save(state);
  }

  Future<void> setBackgroundIndex(int i) async {
    state = state.copyWith(backgroundIndex: i);
    await _repo.save(state);
  }

  Future<void> setPageMode(PageMode mode) async {
    state = state.copyWith(pageMode: mode);
    await _repo.save(state);
  }

  Future<void> setFollowSystemDark(bool v) async {
    state = state.copyWith(followSystemDark: v);
    await _repo.save(state);
  }

  Future<void> setFontFamilyIndex(int i) async {
    state = state.copyWith(fontFamilyIndex: i);
    await _repo.save(state);
  }

  Future<void> setBrightness(double? v) async {
    state = state.copyWith(brightness: v);
    await _repo.save(state);
  }

  Future<void> setAutoReadSpeed(int v) async {
    state = state.copyWith(autoReadSpeed: v);
    await _repo.save(state);
  }

  Future<void> setTtsRate(double v) async {
    state = state.copyWith(ttsRate: v);
    await _repo.save(state);
  }

  Future<void> setTtsPitch(double v) async {
    state = state.copyWith(ttsPitch: v);
    await _repo.save(state);
  }

  Future<void> setTtsVoice(String v) async {
    state = state.copyWith(ttsVoice: v);
    await _repo.save(state);
  }

  Future<void> setTraditionalChinese(bool v) async {
    state = state.copyWith(traditionalChinese: v);
    await _repo.save(state);
  }
}
