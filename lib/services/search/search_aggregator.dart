import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';

/// 多源并发搜索聚合器。
///
/// 职责：
///   - 并发跑所有书源的 [SingleSourceSearcher.search]
///   - 单源超时（默认 8s）→ 该源返回空，不影响其他
///   - 单源抛异常 → 该源返回空
///   - 合并所有结果，按 `dedupKey` 去重，相同 key 的合并 `sources` 列表
///   - 返回 [List<SearchResult>]，按 `sources.length` 倒序（多源覆盖优先）
class SearchAggregator {
  final SingleSourceSearcher searcher;
  final Duration perSourceTimeout;

  SearchAggregator({
    required this.searcher,
    this.perSourceTimeout = const Duration(seconds: 8),
  });

  Future<List<SearchResult>> search(
    String keyword,
    List<BookSource> sources,
  ) async {
    final futures = sources
        .map((s) => searcher
            .search(keyword, s)
            .timeout(perSourceTimeout, onTimeout: () => const [])
            .catchError((_) => <SearchResult>[]))
        .toList();

    final perSourceResults = await Future.wait(futures);
    final flat = perSourceResults.expand((r) => r).toList();
    return _mergeAndDedupe(flat);
  }

  /// 合并去重：相同 dedupKey 的结果合并 sources 列表，补充缺失的可选字段。
  /// 最终按 sources 数量倒序排列。
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
