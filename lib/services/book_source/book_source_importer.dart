import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_source/book_source_validator.dart';

/// 书源导入器。
///
/// 解析用户粘贴 / 远程订阅拉取到的书源 JSON 文本，
/// 校验 + 去重后返回 [BookSource] 列表。
///
/// 支持两种 JSON 形态：
///   1. 单个对象：`{ "bookSourceName": "...", ... }`
///   2. 数组：`[ {...}, {...} ]`
class BookSourceImporter {
  /// 解析 [jsonText]，返回去重后的书源列表。
  ///
  /// - [throwOnInvalid] 为 true（默认）时，遇到无效书源抛异常；
  ///   为 false 时跳过无效条目继续解析。
  List<BookSource> parse(String jsonText, {bool throwOnInvalid = true}) {
    final trimmed = jsonText.trim();
    if (trimmed.isEmpty) return [];

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (e) {
      throw BookSourceValidationException('JSON 解析失败: $e');
    }

    final List<Map<String, dynamic>> rawList;
    if (decoded is List) {
      rawList = decoded.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    } else if (decoded is Map) {
      rawList = [decoded.cast<String, dynamic>()];
    } else {
      throw BookSourceValidationException('JSON 必须是对象或数组');
    }

    final seen = <String>{};
    final result = <BookSource>[];
    for (final raw in rawList) {
      try {
        validateBookSource(raw);
      } on BookSourceValidationException {
        if (throwOnInvalid) rethrow;
        continue;
      }
      final source = BookSource.fromJson(raw);
      if (seen.add(source.bookSourceUrl)) {
        result.add(source);
      }
    }
    return result;
  }
}
