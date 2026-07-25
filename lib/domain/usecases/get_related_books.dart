import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/search/search_aggregator.dart';

/// 「相关推荐」用例 (D-2)。
///
/// 给定当前书的 [SearchResult]，基于作者名与分类关键字做 1-2 次聚合搜索，
/// 排除自身后按源数倒序返回前 [limit] 条作为推荐列表。
///
/// 设计取舍：
///   - 不引入新的网络入口，直接复用 [SearchAggregator]
///   - 不缓存（推荐结果非高频访问，每次进入详情页拉一次即可）
///   - 失败静默：任何子查询失败都返回已收集到的部分结果
class GetRelatedBooks {
  final SearchAggregator _aggregator;
  final Future<List<BookSource>> Function() _getEnabledSources;

  GetRelatedBooks({
    required SearchAggregator aggregator,
    required Future<List<BookSource>> Function() getEnabledSources,
  })  : _aggregator = aggregator,
        _getEnabledSources = getEnabledSources;

  /// 拉取与 [current] 相关的推荐书籍。
  ///
  /// [onProgress] 透传给 [SearchAggregator.search]，可用于 UI 展示进度。
  Future<List<SearchResult>> call(
    SearchResult current, {
    int limit = 6,
    void Function(SearchProgress progress)? onProgress,
  }) async {
    final sources = await _getEnabledSources();
    if (sources.isEmpty) return const [];

    final selfKey = current.dedupKey;
    final all = <SearchResult>[];

    // 1. 按作者搜索（最稳定的信号）
    if (current.author.trim().isNotEmpty) {
      try {
        final list = await _aggregator.search(current.author, sources,
            onProgress: onProgress);
        all.addAll(list);
      } catch (_) {
        // 静默：继续尝试其他关键词
      }
    }

    // 2. 按分类首词搜索（扩大候选池）
    final kind = _firstKind(current.kind);
    if (kind != null && all.length < limit * 3) {
      try {
        final list = await _aggregator.search(kind, sources,
            onProgress: onProgress);
        all.addAll(list);
      } catch (_) {
        // 静默
      }
    }

    if (all.isEmpty) return const [];

    // 3. 合并去重 + 排除自身
    final merged = _mergeAndDedupe(all);
    return merged.where((r) => r.dedupKey != selfKey).take(limit).toList();
  }

  String? _firstKind(String? kind) {
    if (kind == null || kind.trim().isEmpty) return null;
    final first = kind.split(RegExp(r'[,，、\s]+')).first;
    return first.trim().isEmpty ? null : first.trim();
  }

  List<SearchResult> _mergeAndDedupe(List<SearchResult> all) {
    final map = <String, SearchResult>{};
    for (final r in all) {
      final key = r.dedupKey;
      final existing = map[key];
      if (existing == null) {
        map[key] = r;
      } else {
        map[key] = existing.mergeWith(r);
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.sources.length.compareTo(a.sources.length));
    return list;
  }
}
