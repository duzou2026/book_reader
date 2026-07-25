import 'dart:convert';

import 'package:hive/hive.dart';

/// 章节书签。
class Bookmark {
  /// ID：bookId_chapterIndex。
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterName;

  /// 可选的备注。
  final String? note;

  /// 创建时间（毫秒）。
  final int createdAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterName,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'chapterName': chapterName,
        'note': note,
        'createdAt': createdAt,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      chapterIndex: json['chapterIndex'] as int,
      chapterName: json['chapterName'] as String,
      note: json['note'] as String?,
      createdAt: json['createdAt'] as int,
    );
  }
}

/// 书签仓储（Hive）。
class BookmarkRepository {
  final Box<String> _box;
  BookmarkRepository(this._box);

  static const String boxName = 'bookmarks';

  Future<List<Bookmark>> getByBook(String bookId) async {
    final list = _box.values
        .map((s) => Bookmark.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((b) => b.bookId == bookId)
        .toList();
    list.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return list;
  }

  Future<void> add(Bookmark bookmark) async {
    await _box.put(bookmark.id, jsonEncode(bookmark.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<bool> exists(String id) => Future.value(_box.containsKey(id));

  Future<void> toggle(Bookmark bookmark) async {
    if (await exists(bookmark.id)) {
      await delete(bookmark.id);
    } else {
      await add(bookmark);
    }
  }
}
