import 'package:book_reader/data/models/search_result.dart';

/// 搜索结果缓存（内存版）。
///
/// 同一关键词在 TTL 内复用上次结果，避免重复请求多源。
/// 用户可手动「刷新」绕过缓存。
class SearchResultCache {
  SearchResultCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;

  /// key = 关键词；value = (结果, 过期时间戳 ms)。
  final Map<String, _CacheEntry> _map = {};

  /// 读取缓存；过期或不存在返回 null。
  List<SearchResult>? get(String keyword) {
    final e = _map[keyword];
    if (e == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > e.expireAt) {
      _map.remove(keyword);
      return null;
    }
    return List.unmodifiable(e.results);
  }

  void put(String keyword, List<SearchResult> results) {
    _map[keyword] = _CacheEntry(
      results: List.of(results),
      expireAt:
          DateTime.now().millisecondsSinceEpoch + ttl.inMilliseconds,
    );
  }

  void invalidate(String keyword) => _map.remove(keyword);

  void clear() => _map.clear();

  bool has(String keyword) {
    final e = _map[keyword];
    if (e == null) return false;
    if (DateTime.now().millisecondsSinceEpoch > e.expireAt) {
      _map.remove(keyword);
      return false;
    }
    return true;
  }
}

class _CacheEntry {
  final List<SearchResult> results;
  final int expireAt;
  const _CacheEntry({required this.results, required this.expireAt});
}

/// 搜索结果排序方式。
enum SearchResultSort {
  /// 源数倒序（默认：覆盖多源优先）。
  sourceCount,
  /// 字数倒序（长篇优先）。
  wordCount,
  /// 书名升序。
  title,
}

/// 应用排序：对未知字数的条目按 0 处理。
List<SearchResult> sortSearchResults(
    List<SearchResult> src, SearchResultSort sort) {
  final list = src.toList();
  switch (sort) {
    case SearchResultSort.sourceCount:
      list.sort((a, b) => b.sources.length.compareTo(a.sources.length));
      break;
    case SearchResultSort.wordCount:
      list.sort((a, b) =>
          _parseWordCount(b.wordCount).compareTo(_parseWordCount(a.wordCount)));
      break;
    case SearchResultSort.title:
      list.sort((a, b) => a.bookName.compareTo(b.bookName));
      break;
  }
  return list;
}

/// 解析字数：'88万字' → 880000；'1.5亿字' → 150000000。
int _parseWordCount(String? s) {
  if (s == null || s.isEmpty) return 0;
  final cleaned = s.replaceAll(RegExp(r'[^\d.亿万]'), '');
  if (cleaned.isEmpty) return 0;
  final num = double.tryParse(cleaned);
  if (num == null) return 0;
  if (s.contains('亿')) return (num * 100000000).toInt();
  if (s.contains('万')) return (num * 10000).toInt();
  return num.toInt();
}
