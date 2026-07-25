import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  const ReadingPrefs({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.backgroundIndex = 0,
    this.pageMode = PageMode.scroll,
    this.followSystemDark = false,
  });

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'backgroundIndex': backgroundIndex,
        'pageMode': pageMode.name,
        'followSystemDark': followSystemDark,
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
    );
  }

  ReadingPrefs copyWith({
    double? fontSize,
    double? lineHeight,
    int? backgroundIndex,
    PageMode? pageMode,
    bool? followSystemDark,
  }) {
    return ReadingPrefs(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      backgroundIndex: backgroundIndex ?? this.backgroundIndex,
      pageMode: pageMode ?? this.pageMode,
      followSystemDark: followSystemDark ?? this.followSystemDark,
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
}
