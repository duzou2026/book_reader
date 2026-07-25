import 'dart:convert';

import 'package:hive/hive.dart';

/// 单本书的阅读进度。
class ReadingProgress {
  /// 唯一 ID（与 [BookshelfEntry.id] 一致：`bookName|author`）。
  final String id;

  /// 最近阅读章节索引（从 0 开始）。
  final int chapterIndex;

  /// 章节内滚动偏移（像素）。
  final double scrollOffset;

  /// 最近阅读时间（毫秒时间戳）。
  final int lastReadAt;

  /// 最近一次切换后的源 URL（用于续读时定位源）。
  /// null 表示使用原书源。
  final String? switchedSourceUrl;

  const ReadingProgress({
    required this.id,
    required this.chapterIndex,
    required this.scrollOffset,
    required this.lastReadAt,
    this.switchedSourceUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapterIndex': chapterIndex,
        'scrollOffset': scrollOffset,
        'lastReadAt': lastReadAt,
        'switchedSourceUrl': switchedSourceUrl,
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      id: json['id'] as String,
      chapterIndex: json['chapterIndex'] as int,
      scrollOffset: (json['scrollOffset'] as num).toDouble(),
      lastReadAt: json['lastReadAt'] as int,
      switchedSourceUrl: json['switchedSourceUrl'] as String?,
    );
  }

  ReadingProgress copyWith({
    int? chapterIndex,
    double? scrollOffset,
    int? lastReadAt,
    String? switchedSourceUrl,
  }) {
    return ReadingProgress(
      id: id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      switchedSourceUrl: switchedSourceUrl ?? this.switchedSourceUrl,
    );
  }
}

/// 阅读进度 Hive 仓储。
///
/// Box: `'reading_progress'`，key = [ReadingProgress.id]，value = JSON 字符串。
class ReadingProgressRepository {
  final Box<String> _box;
  ReadingProgressRepository(this._box);

  static const String boxName = 'reading_progress';

  Future<ReadingProgress?> get(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return ReadingProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> upsert(ReadingProgress progress) async {
    await _box.put(progress.id, jsonEncode(progress.toJson()));
  }

  /// 便捷方法：仅更新章节索引 + 时间。
  Future<void> updateChapter({
    required String id,
    required int chapterIndex,
    String? switchedSourceUrl,
  }) async {
    final existing = await get(id);
    final updated = (existing ?? ReadingProgress(
      id: id,
      chapterIndex: chapterIndex,
      scrollOffset: 0,
      lastReadAt: 0,
    ))
        .copyWith(
      chapterIndex: chapterIndex,
      lastReadAt: DateTime.now().millisecondsSinceEpoch,
      switchedSourceUrl: switchedSourceUrl,
    );
    await upsert(updated);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
