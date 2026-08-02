import 'package:book_reader/data/models/search_result.dart';

/// 搜索结果缓存（内存版）。
///
/// 同一关键词在 TTL 内复用上次结果，避免重复请求多源。
/// 用户可手动「刷新」绕过缓存。
///
/// 空结果用短 TTL（30s），避免因瞬时网络问题返回空后，
/// 短时间内重搜仍命中空缓存导致用户以为"搜不到"。
///
/// 超过 [maxEntries] 时淘汰最旧的条目；每次 put/get 自动清理过期条目。
class SearchResultCache {
  SearchResultCache({
    this.ttl = const Duration(minutes: 5),
    this.emptyTtl = const Duration(seconds: 30),
    this.maxEntries = 50,
  });

  /// 非空结果的缓存时长。
  final Duration ttl;

  /// 空结果的缓存时长（短，避免网络抖动导致的空结果长期缓存）。
  final Duration emptyTtl;

  /// 缓存条目上限，超出则淘汰最旧的。
  final int maxEntries;

  /// key = 关键词；value = (结果, 过期时间戳 ms)。
  final Map<String, _CacheEntry> _map = {};

  /// 清理过期条目并返回剩余数量。
  int _evictExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = <String>[];
    for (final e in _map.entries) {
      if (now > e.value.expireAt) expired.add(e.key);
    }
    for (final k in expired) _map.remove(k);
    return _map.length;
  }

  /// 超出上限时淘汰最旧的（按过期时间+最近最少使用近似）。
  void _evictIfNeeded() {
    if (_map.length <= maxEntries) return;
    final entries = _map.entries.toList()
      ..sort((a, b) => a.value.expireAt.compareTo(b.value.expireAt));
    final toRemove = entries.sublist(0, _map.length - maxEntries);
    for (final e in toRemove) _map.remove(e.key);
  }

  /// 读取缓存；过期或不存在返回 null。
  List<SearchResult>? get(String keyword) {
    final remaining = _evictExpired();
    if (remaining == 0) return null;
    final e = _map[keyword];
    if (e == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > e.expireAt) {
      _map.remove(keyword);
      return null;
    }
    return List.unmodifiable(e.results);
  }

  void put(String keyword, List<SearchResult> results) {
    _evictExpired();
    final duration = results.isEmpty ? emptyTtl : ttl;
    _map[keyword] = _CacheEntry(
      results: List.of(results),
      expireAt:
          DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds,
    );
    _evictIfNeeded();
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
  /// 相关性排序（默认：综合书名匹配度+作者匹配度+源数+字数）。
  relevance,
  /// 源数倒序（覆盖多源优先）。
  sourceCount,
  /// 字数倒序（长篇优先）。
  wordCount,
  /// 书名升序。
  title,
}

/// 应用排序：对未知字数的条目按 0 处理。
List<SearchResult> sortSearchResults(
  List<SearchResult> src,
  SearchResultSort sort, {
  String? keyword,
}) {
  final list = src.toList();
  switch (sort) {
    case SearchResultSort.relevance:
      _sortByRelevance(list, keyword ?? '');
      break;
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

/// 相关性排序：综合书名匹配度、作者匹配度、源数、字数计算综合得分。
///
/// 评分权重：
/// - 书名精确匹配（与关键词完全相等）：+200
/// - 书名包含关键词：+100 + 额外匹配位置加分
/// - 书名与关键词子串重叠长度加分：按重叠字符数 +3/字
/// - 作者精确匹配：+50
/// - 作者包含关键词：+20
/// - 源数加成：sources.length * 10
/// - 字数加成：log10(字数) * 5（长篇小说略占优，但不影响相关性主导）
void _sortByRelevance(List<SearchResult> list, String keyword) {
  final kw = keyword.toLowerCase().trim();
  if (kw.isEmpty) {
    list.sort((a, b) => b.sources.length.compareTo(a.sources.length));
    return;
  }
  int score(SearchResult r) {
    var s = 0;
    final name = r.bookName.toLowerCase();
    final author = r.author.toLowerCase();

    if (name == kw) {
      s += 200;
    } else if (name.contains(kw)) {
      s += 100;
      // 越靠近开头加分越多
      final idx = name.indexOf(kw);
      s += (20 - idx).clamp(0, 20);
    } else {
      // 子串重叠：关键词中连续字符出现在书名中的长度
      var overlap = 0;
      for (var len = kw.length; len >= 2; len--) {
        var found = false;
        for (var i = 0; i <= kw.length - len; i++) {
          final sub = kw.substring(i, i + len);
          if (name.contains(sub)) {
            overlap = len;
            found = true;
            break;
          }
        }
        if (found) break;
      }
      s += overlap * 3;
    }

    if (author == kw) {
      s += 50;
    } else if (author.isNotEmpty && author.contains(kw)) {
      s += 20;
    }

    s += r.sources.length * 10;

    final wc = _parseWordCount(r.wordCount);
    if (wc > 0) {
      final logWc = _log10(wc);
      s += (logWc * 5).toInt();
    }
    return s;
  }

  list.sort((a, b) => score(b).compareTo(score(a)));
}

double _log10(int x) {
  if (x <= 0) return 0;
  return x.toString().length - 1 +
      (x / _pow10(x.toString().length - 1)).toStringAsFixed(6).length / 10;
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) r *= 10;
  return r;
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
