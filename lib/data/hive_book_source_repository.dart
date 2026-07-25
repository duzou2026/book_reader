import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/domain/usecases/search_books.dart' show BookSourceRepository;
import 'package:hive/hive.dart';

/// 以 `bookSourceUrl` 为 Hive key、`BookSource` 的 JSON 字符串为 value 的存储方案。
///
/// 不为 freezed 模型生成 Hive TypeAdapter，避免为嵌套 Rule* 类全部生成 adapter。
/// 读写频率低（导入/删除），JSON 序列化开销可接受。
class HiveBookSourceRepository implements BookSourceRepository {
  final Box<String> _box;
  HiveBookSourceRepository(this._box);

  @override
  Future<List<BookSource>> getEnabledSources() async {
    return _box.values
        .map((s) => BookSource.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .where((s) => s.enabled)
        .toList();
  }

  @override
  Future<void> upsert(BookSource source) async {
    await _box.put(source.bookSourceUrl, jsonEncode(source.toJson()));
  }

  @override
  Future<void> deleteByUrl(String bookSourceUrl) async {
    await _box.delete(bookSourceUrl);
  }

  /// 返回全部书源（含禁用），供管理页使用。
  @override
  Future<List<BookSource>> getAll() async {
    return _box.values
        .map((s) => BookSource.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> setEnabled(String bookSourceUrl, bool enabled) async {
    final raw = _box.get(bookSourceUrl);
    if (raw == null) return;
    final source = BookSource.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await _box.put(bookSourceUrl, jsonEncode(source.copyWith(enabled: enabled).toJson()));
  }
}
