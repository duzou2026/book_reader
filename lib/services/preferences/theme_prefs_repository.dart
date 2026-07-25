import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// App 全局主题模式。
enum AppThemeMode {
  /// 跟随系统。
  system,
  /// 始终浅色。
  light,
  /// 始终深色。
  dark,
}

/// App 主题偏好。
class ThemePrefs {
  /// 主题模式。
  final AppThemeMode mode;

  /// 主题色种子（ARGB int）。
  final int seedColor;

  const ThemePrefs({
    this.mode = AppThemeMode.system,
    this.seedColor = 0xFF00897B, // Colors.teal
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'seedColor': seedColor,
      };

  factory ThemePrefs.fromJson(Map<String, dynamic> json) {
    return ThemePrefs(
      mode: AppThemeMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => AppThemeMode.system,
      ),
      seedColor: (json['seedColor'] as num?)?.toInt() ?? 0xFF00897B,
    );
  }

  ThemePrefs copyWith({
    AppThemeMode? mode,
    int? seedColor,
  }) {
    return ThemePrefs(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
    );
  }
}

/// 主题偏好 Hive 仓储。
///
/// 复用 `reading_prefs` Box，独立 key `'theme'` 存储。
class ThemePrefsRepository {
  final Box<String> _box;
  ThemePrefsRepository(this._box);

  static const String _key = 'theme';

  Future<ThemePrefs> get() async {
    final raw = _box.get(_key);
    if (raw == null) return const ThemePrefs();
    return ThemePrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ThemePrefs prefs) async {
    await _box.put(_key, jsonEncode(prefs.toJson()));
  }
}

/// 响应式的主题偏好 Notifier。
class ThemePrefsNotifier extends StateNotifier<ThemePrefs> {
  final ThemePrefsRepository _repo;

  ThemePrefsNotifier(this._repo) : super(const ThemePrefs()) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.get();
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _repo.save(state);
  }

  Future<void> setSeedColor(int color) async {
    state = state.copyWith(seedColor: color);
    await _repo.save(state);
  }
}
