import 'dart:convert';

import 'package:hive/hive.dart';

/// 阅读历史条目：一次「打开某章节」的记录。
///
/// 与 [BookshelfEntry] 区别：
/// - 书架只保存收藏的书；阅读历史记录所有打开过的书（即便未加入书架）。
/// - 书架只保存最近一次阅读位置；阅读历史按时间序列保存每一次阅读。
class ReadingHistoryEntry {
  /// 唯一 ID：时间戳 + bookId，避免冲突。
  final String id;

  /// 书籍归一化 ID：`bookName|author`。
  final String bookId;

  final String bookName;
  final String author;
  final String? coverUrl;

  /// 当时使用的书源信息（用于「继续阅读」时复用）。
  final String sourceName;
  final String sourceUrl;
  final String bookUrl;

  final int chapterIndex;
  final String chapterName;

  /// 本次阅读时长（秒）。
  final int durationSeconds;

  /// 阅读时间（毫秒时间戳）。
  final int readAt;

  const ReadingHistoryEntry({
    required this.id,
    required this.bookId,
    required this.bookName,
    required this.author,
    this.coverUrl,
    required this.sourceName,
    required this.sourceUrl,
    required this.bookUrl,
    required this.chapterIndex,
    required this.chapterName,
    this.durationSeconds = 0,
    required this.readAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookName': bookName,
        'author': author,
        'coverUrl': coverUrl,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        'bookUrl': bookUrl,
        'chapterIndex': chapterIndex,
        'chapterName': chapterName,
        'durationSeconds': durationSeconds,
        'readAt': readAt,
      };

  factory ReadingHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReadingHistoryEntry(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      bookName: json['bookName'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String?,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      bookUrl: json['bookUrl'] as String,
      chapterIndex: json['chapterIndex'] as int? ?? 0,
      chapterName: json['chapterName'] as String,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      readAt: json['readAt'] as int,
    );
  }
}

/// 阅读历史 Hive 仓储。
///
/// Box: `'reading_history'`，key = 自增 id。
/// 按时间倒序存储读取，提供按书籍聚合、清理过期记录等能力。
class ReadingHistoryRepository {
  final Box<String> _box;
  ReadingHistoryRepository(this._box);

  static const String boxName = 'reading_history';
  static const int _maxEntries = 500;

  Future<void> add(ReadingHistoryEntry entry) async {
    await _box.put(entry.id, jsonEncode(entry.toJson()));
    // 超出上限时删除最旧记录
    if (_box.length > _maxEntries) {
      final all = await getAll();
      final removeCount = all.length - _maxEntries;
      for (var i = 0; i < removeCount; i++) {
        await _box.delete(all[all.length - 1 - i].id);
      }
    }
  }

  /// 全部历史，按时间倒序。
  Future<List<ReadingHistoryEntry>> getAll() async {
    final list = _box.values
        .map((s) =>
            ReadingHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.readAt.compareTo(a.readAt));
    return list;
  }

  /// 最近 N 条。
  Future<List<ReadingHistoryEntry>> getRecent(int limit) async {
    final all = await getAll();
    if (all.length <= limit) return all;
    return all.sublist(0, limit);
  }

  /// 按书籍聚合：返回每本书最近一次阅读记录。
  Future<List<ReadingHistoryEntry>> getRecentPerBook() async {
    final all = await getAll();
    final seen = <String>{};
    final result = <ReadingHistoryEntry>[];
    for (final e in all) {
      if (seen.add(e.bookId)) {
        result.add(e);
      }
    }
    return result;
  }

  /// 删除单条历史。
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// 清空所有历史。
  Future<void> clear() async {
    await _box.clear();
  }

  /// 删除某本书的所有历史。
  Future<void> deleteByBook(String bookId) async {
    final all = await getAll();
    for (final e in all) {
      if (e.bookId == bookId) {
        await _box.delete(e.id);
      }
    }
  }
}
