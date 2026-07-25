import 'dart:convert';

import 'package:hive/hive.dart';

/// 书架条目：表示用户收藏的一本书。
///
/// 存储方案：Hive Box `'bookshelf'`，key = [id]，value = JSON 字符串。
/// 不为模型生成 TypeAdapter，沿用与 [HiveBookSourceRepository] 一致的简单方案。
///
/// [id] 规则：`bookName|author`（归一化后），保证同一本书在多源间共享同一个书架记录。
class BookshelfEntry {
  /// 唯一 ID（归一化后的 `bookName|author`）。
  final String id;

  final String bookName;
  final String author;
  final String? coverUrl;
  final String? intro;
  final String? kind;
  final String? wordCount;
  final String? lastChapter;

  /// 加入书架时使用的源信息（首个可用源）。
  final String sourceName;
  final String sourceUrl;
  final String bookUrl;

  /// 最近阅读的章节索引（从 0 开始）。
  /// null 表示未开始阅读。
  final int? lastChapterIndex;

  /// 最近阅读章节名（便于在书架展示）。
  final String? lastChapterName;

  /// 上次阅读时间（毫秒时间戳）。
  final int lastReadAt;

  /// 加入书架时间（毫秒时间戳）。
  final int addedAt;

  /// 所属分组名（空字符串表示未分组）。
  final String group;

  const BookshelfEntry({
    required this.id,
    required this.bookName,
    required this.author,
    this.coverUrl,
    this.intro,
    this.kind,
    this.wordCount,
    this.lastChapter,
    required this.sourceName,
    required this.sourceUrl,
    required this.bookUrl,
    this.lastChapterIndex,
    this.lastChapterName,
    required this.lastReadAt,
    required this.addedAt,
    this.group = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookName': bookName,
        'author': author,
        'coverUrl': coverUrl,
        'intro': intro,
        'kind': kind,
        'wordCount': wordCount,
        'lastChapter': lastChapter,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        'bookUrl': bookUrl,
        'lastChapterIndex': lastChapterIndex,
        'lastChapterName': lastChapterName,
        'lastReadAt': lastReadAt,
        'addedAt': addedAt,
        'group': group,
      };

  factory BookshelfEntry.fromJson(Map<String, dynamic> json) {
    return BookshelfEntry(
      id: json['id'] as String,
      bookName: json['bookName'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      wordCount: json['wordCount'] as String?,
      lastChapter: json['lastChapter'] as String?,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      bookUrl: json['bookUrl'] as String,
      lastChapterIndex: json['lastChapterIndex'] as int?,
      lastChapterName: json['lastChapterName'] as String?,
      lastReadAt: json['lastReadAt'] as int,
      addedAt: json['addedAt'] as int,
      group: json['group'] as String? ?? '',
    );
  }

  BookshelfEntry copyWith({
    String? coverUrl,
    String? intro,
    String? kind,
    String? wordCount,
    String? lastChapter,
    String? sourceName,
    String? sourceUrl,
    String? bookUrl,
    int? lastChapterIndex,
    String? lastChapterName,
    int? lastReadAt,
    String? group,
  }) {
    return BookshelfEntry(
      id: id,
      bookName: bookName,
      author: author,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      kind: kind ?? this.kind,
      wordCount: wordCount ?? this.wordCount,
      lastChapter: lastChapter ?? this.lastChapter,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      lastChapterName: lastChapterName ?? this.lastChapterName,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      addedAt: addedAt,
      group: group ?? this.group,
    );
  }

  /// 归一化 ID：`bookName|author`（小写、去前后空白、合并内部空白）。
  static String makeId(String bookName, String author) {
    String norm(String s) =>
        s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    return '${norm(bookName)}|${norm(author)}';
  }

  /// 是否有未读更新：源端最新章节名存在，且与用户最近阅读章节名不同。
  bool get hasUpdate {
    final latest = lastChapter;
    final read = lastChapterName;
    if (latest == null || latest.isEmpty) return false;
    if (read == null || read.isEmpty) return true;
    return latest != read;
  }
}

/// 书架 Hive 仓储。
class BookshelfRepository {
  final Box<String> _box;
  BookshelfRepository(this._box);

  static const String boxName = 'bookshelf';

  Future<List<BookshelfEntry>> getAll() async {
    final list = _box.values
        .map((s) => BookshelfEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return list;
  }

  Future<BookshelfEntry?> getById(String id) async {
    final raw = _box.get(id);
    if (raw == null) return null;
    return BookshelfEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> upsert(BookshelfEntry entry) async {
    await _box.put(entry.id, jsonEncode(entry.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<bool> contains(String id) async {
    return _box.containsKey(id);
  }

  /// 更新最近阅读章节 + 时间。
  Future<void> updateReadingProgress({
    required String id,
    required int chapterIndex,
    required String chapterName,
  }) async {
    final entry = await getById(id);
    if (entry == null) return;
    await upsert(entry.copyWith(
      lastChapterIndex: chapterIndex,
      lastChapterName: chapterName,
      lastReadAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 更新所属分组。传入空字符串表示移出分组。
  Future<void> updateGroup({
    required String id,
    required String group,
  }) async {
    final entry = await getById(id);
    if (entry == null) return;
    await upsert(entry.copyWith(group: group));
  }

  /// 获取所有已使用的分组名（去重，按字母序）。
  Future<List<String>> getAllGroups() async {
    final all = await getAll();
    final set = all.map((e) => e.group).where((g) => g.isNotEmpty).toSet();
    final list = set.toList()..sort();
    return list;
  }

  /// 更新源端最新章节名（用于更新提醒：检查追更）。
  Future<void> updateLatestChapter({
    required String id,
    required String? latestChapter,
  }) async {
    final entry = await getById(id);
    if (entry == null) return;
    await upsert(entry.copyWith(lastChapter: latestChapter));
  }
}

/// 书架排序方式。
enum BookshelfSort {
  /// 按最近阅读时间倒序。
  recent,
  /// 按加入时间倒序。
  added,
  /// 按书名升序。
  title,
}

/// 书架视图模式。
enum BookshelfViewMode {
  /// 列表视图。
  list,
  /// 网格视图。
  grid,
}
