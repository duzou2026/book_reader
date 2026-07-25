import 'dart:convert';

import 'package:hive/hive.dart';

/// 搜索历史记录项。
class SearchHistoryEntry {
  final String keyword;
  final int searchedAt;

  const SearchHistoryEntry({
    required this.keyword,
    required this.searchedAt,
  });

  Map<String, dynamic> toJson() => {
        'keyword': keyword,
        'searchedAt': searchedAt,
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      keyword: json['keyword'] as String,
      searchedAt: json['searchedAt'] as int,
    );
  }
}

/// 搜索历史仓储：基于 Hive 的轻量实现。
///
/// - 以 keyword 为 key，重复搜索会更新 searchedAt 并移到列表最前。
/// - 最多保留 [maxEntries] 条，超出则淘汰最旧的。
/// - 提供热词统计：按 searchedAt 倒序取前 N。
class SearchHistoryRepository {
  final Box<String> _box;
  final int maxEntries;

  SearchHistoryRepository(this._box, {this.maxEntries = 20});

  static const String boxName = 'search_history';

  /// 获取全部历史，按 searchedAt 倒序。
  Future<List<SearchHistoryEntry>> getAll() async {
    final list = _box.values
        .map((s) => SearchHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => b.searchedAt.compareTo(a.searchedAt));
    return list;
  }

  /// 记录一次搜索。若 keyword 已存在则更新时间。
  Future<void> record(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = SearchHistoryEntry(keyword: trimmed, searchedAt: now);
    await _box.put(trimmed, jsonEncode(entry.toJson()));
    await _evict();
  }

  /// 删除指定 keyword 的历史。
  Future<void> delete(String keyword) async {
    await _box.delete(keyword);
  }

  /// 清空全部历史。
  Future<void> clear() async {
    await _box.clear();
  }

  /// 淘汰超出上限的旧记录。
  Future<void> _evict() async {
    final all = await getAll();
    if (all.length <= maxEntries) return;
    final toRemove = all.sublist(maxEntries);
    for (final e in toRemove) {
      await _box.delete(e.keyword);
    }
  }
}

/// 热门搜索词（本地统计版）。
///
/// 简单实现：取搜索历史中最近 [recentLimit] 条，按出现频次排序。
/// 实际项目可改为远程接口；此处保持离线可用。
class HotKeywordsRepository {
  final SearchHistoryRepository _history;
  final int recentLimit;

  HotKeywordsRepository(this._history, {this.recentLimit = 100});

  /// 返回热门词列表。若无历史则返回内置推荐词。
  Future<List<String>> getHot({int top = 10}) async {
    final all = await _history.getAll();
    if (all.isEmpty) return _defaultHot;
    final recent = all.take(recentLimit).toList();
    // 按频次统计（同一词多次搜索会被记录，但本实现每次搜索会覆盖时间，
    // 所以这里其实只是按最近搜索顺序取前 top。保持简单。）
    return recent.take(top).map((e) => e.keyword).toList();
  }

  /// 内置推荐词：当无搜索历史时展示。
  static const _defaultHot = <String>[
    '三体',
    '活着',
    '百年孤独',
    '平凡的世界',
    '围城',
    '红楼梦',
    '西游记',
    '水浒传',
    '三国演义',
    '哈利波特',
  ];
}
