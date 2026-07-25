import 'dart:convert';

import 'package:hive/hive.dart';

/// 单日阅读统计。
class DailyReadingStat {
  /// 日期 YYYY-MM-DD。
  final String date;

  /// 当日阅读时长（秒）。
  final int durationSeconds;

  /// 当日阅读字数。
  final int wordCount;

  const DailyReadingStat({
    required this.date,
    required this.durationSeconds,
    required this.wordCount,
  });

  DailyReadingStat copyWith({int? durationSeconds, int? wordCount}) {
    return DailyReadingStat(
      date: date,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      wordCount: wordCount ?? this.wordCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'durationSeconds': durationSeconds,
        'wordCount': wordCount,
      };

  factory DailyReadingStat.fromJson(Map<String, dynamic> json) {
    return DailyReadingStat(
      date: json['date'] as String,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      wordCount: json['wordCount'] as int? ?? 0,
    );
  }
}

/// 阅读统计仓储（Hive）。
///
/// 以日期为 key 存储每日累计的阅读时长和字数。
class ReadingStatsRepository {
  final Box<String> _box;
  ReadingStatsRepository(this._box);

  static const String boxName = 'reading_stats';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DailyReadingStat> get(String date) async {
    final raw = _box.get(date);
    if (raw == null) {
      return DailyReadingStat(date: date, durationSeconds: 0, wordCount: 0);
    }
    return DailyReadingStat.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<DailyReadingStat> getToday() => get(_today());

  /// 累加今日阅读时长和字数。
  Future<void> addToday({int durationSeconds = 0, int wordCount = 0}) async {
    final date = _today();
    final current = await get(date);
    final updated = current.copyWith(
      durationSeconds: current.durationSeconds + durationSeconds,
      wordCount: current.wordCount + wordCount,
    );
    await _box.put(date, jsonEncode(updated.toJson()));
  }

  /// 获取最近 N 天的统计（含今天，按日期升序）。
  Future<List<DailyReadingStat>> getRecentDays(int days) async {
    final today = DateTime.now();
    final result = <DailyReadingStat>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      result.add(await get(key));
    }
    return result;
  }

  /// 获取全部统计记录（按日期倒序）。
  Future<List<DailyReadingStat>> getAll() async {
    final list = _box.values
        .map((s) => DailyReadingStat.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// 累计阅读时长（秒）。
  Future<int> getTotalDurationSeconds() async {
    final all = await getAll();
    return all.fold<int>(0, (sum, s) => sum + s.durationSeconds);
  }

  /// 累计阅读字数。
  Future<int> getTotalWordCount() async {
    final all = await getAll();
    return all.fold<int>(0, (sum, s) => sum + s.wordCount);
  }
}
