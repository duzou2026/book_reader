import 'dart:convert';

import 'package:hive/hive.dart';

/// 章节正文缓存条目。
///
/// 序列化为 JSON 字符串存入 Hive（与 BookSourceRepository 同样的策略，
/// 避免为 Chapter 生成 TypeAdapter）。
class CachedChapter {
  /// 缓存 key：`$bookUrl|$chapterUrl`（与 [ChapterCacheRepository.makeKey] 一致）。
  final String key;

  /// 所属书的 bookUrl（用于按书清理）。
  final String bookUrl;

  /// 章节正文。
  final String content;

  /// 章节名（用于离线列表展示）。
  final String chapterName;

  /// 章节序号（从 1 开始）。
  final int chapterIndex;

  /// 缓存时间戳（ms）。
  final int cachedAt;

  /// 来源书源 URL（用于按源失效）。
  final String sourceUrl;

  const CachedChapter({
    required this.key,
    required this.bookUrl,
    required this.content,
    required this.chapterName,
    required this.chapterIndex,
    required this.cachedAt,
    required this.sourceUrl,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'bookUrl': bookUrl,
        'content': content,
        'chapterName': chapterName,
        'chapterIndex': chapterIndex,
        'cachedAt': cachedAt,
        'sourceUrl': sourceUrl,
      };

  factory CachedChapter.fromJson(Map<String, dynamic> json) => CachedChapter(
        key: json['key'] as String,
        bookUrl: json['bookUrl'] as String,
        content: json['content'] as String,
        chapterName: json['chapterName'] as String,
        chapterIndex: (json['chapterIndex'] as num).toInt(),
        cachedAt: (json['cachedAt'] as num).toInt(),
        sourceUrl: json['sourceUrl'] as String,
      );
}

/// 章节正文持久化缓存（E-1）。
///
/// 以 Hive Box<String> 存储，key 为 `bookUrl|chapterUrl`，value 为 JSON。
/// 提供按书清理、按源失效等管理方法。
class ChapterCacheRepository {
  final Box<String> _box;
  ChapterCacheRepository(this._box);

  /// 构造缓存 key。
  static String makeKey(String bookUrl, String chapterUrl) =>
      '$bookUrl|$chapterUrl';

  /// 读取一条缓存。不存在或解析失败返回 null。
  CachedChapter? get(String bookUrl, String chapterUrl) {
    final raw = _box.get(makeKey(bookUrl, chapterUrl));
    if (raw == null) return null;
    try {
      return CachedChapter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 是否已缓存。
  bool has(String bookUrl, String chapterUrl) =>
      _box.containsKey(makeKey(bookUrl, chapterUrl));

  /// 写入缓存。已存在则覆盖。
  Future<void> put(CachedChapter entry) async {
    await _box.put(entry.key, jsonEncode(entry.toJson()));
  }

  /// 删除单条。
  Future<void> delete(String bookUrl, String chapterUrl) async {
    await _box.delete(makeKey(bookUrl, chapterUrl));
  }

  /// 删除某书的所有缓存。
  Future<int> deleteForBook(String bookUrl) async {
    final keys = _box.keys
        .where((k) => k is String && k.startsWith('$bookUrl|'))
        .cast<String>()
        .toList();
    for (final k in keys) {
      await _box.delete(k);
    }
    return keys.length;
  }

  /// 删除某源的所有缓存（用于书源被删除/禁用时失效）。
  Future<int> deleteForSource(String sourceUrl) async {
    final toDelete = <String>[];
    for (final raw in _box.values) {
      try {
        final c = CachedChapter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (c.sourceUrl == sourceUrl) toDelete.add(c.key);
      } catch (_) {
        continue;
      }
    }
    for (final k in toDelete) {
      await _box.delete(k);
    }
    return toDelete.length;
  }

  /// 列出某书的所有缓存（按章节序号升序）。
  List<CachedChapter> listForBook(String bookUrl) {
    final result = <CachedChapter>[];
    for (final raw in _box.values) {
      try {
        final c = CachedChapter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (c.bookUrl == bookUrl) result.add(c);
      } catch (_) {
        continue;
      }
    }
    result.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return result;
  }

  /// 该书已缓存的章节数量。
  int countForBook(String bookUrl) {
    var n = 0;
    for (final raw in _box.values) {
      try {
        final c = CachedChapter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        if (c.bookUrl == bookUrl) n++;
      } catch (_) {
        continue;
      }
    }
    return n;
  }

  /// 清空全部缓存。
  Future<void> clear() async {
    await _box.clear();
  }
}
