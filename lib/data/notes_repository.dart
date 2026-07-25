import 'dart:convert';

import 'package:hive/hive.dart';

/// 划线笔记。
class Note {
  /// 笔记 ID：bookId_chapterIndex_offset。
  final String id;
  final String bookId;
  final int chapterIndex;
  final String chapterName;

  /// 划线文本。
  final String text;

  /// 用户感想（可选）。
  final String? thought;

  /// 创建时间（毫秒）。
  final int createdAt;

  const Note({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterName,
    required this.text,
    this.thought,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'chapterName': chapterName,
        'text': text,
        'thought': thought,
        'createdAt': createdAt,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      chapterIndex: json['chapterIndex'] as int,
      chapterName: json['chapterName'] as String,
      text: json['text'] as String,
      thought: json['thought'] as String?,
      createdAt: json['createdAt'] as int,
    );
  }

  Note copyWith({String? thought}) {
    return Note(
      id: id,
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterName: chapterName,
      text: text,
      thought: thought ?? this.thought,
      createdAt: createdAt,
    );
  }
}

/// 笔记仓储（Hive）。
class NoteRepository {
  final Box<String> _box;
  NoteRepository(this._box);

  static const String boxName = 'notes';

  Future<List<Note>> getByBook(String bookId) async {
    final list = _box.values
        .map((s) => Note.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((n) => n.bookId == bookId)
        .toList();
    list.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
    return list;
  }

  Future<List<Note>> getAll() async {
    final list = _box.values
        .map((s) => Note.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> add(Note note) async {
    await _box.put(note.id, jsonEncode(note.toJson()));
  }

  Future<void> updateThought(String id, String thought) async {
    final raw = _box.get(id);
    if (raw == null) return;
    final note = Note.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await _box.put(id, jsonEncode(note.copyWith(thought: thought).toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<bool> exists(String id) => Future.value(_box.containsKey(id));
}
