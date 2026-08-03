import 'dart:async';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';

/// 搜索进度快照。
class SearchProgress {
  /// 已完成的源数量（含成功、超时、失败）。
  final int completed;

  /// 总源数量。
  final int total;

  /// 各源的完成状态：sourceName → (ok | empty | timeout | error)。
  final Map<String, String> sourceStatus;

  /// 当前已聚合的结果数量（去重前）。
  final int resultCount;

  const SearchProgress({
    required this.completed,
    required this.total,
    required this.sourceStatus,
    required this.resultCount,
  });

  bool get isDone => completed >= total;

  @override
  String toString() => 'SearchProgress($completed/$total, results=$resultCount)';
}

/// 多源并发搜索聚合器。
///
/// 职责：
///   - 以固定并发度跑所有书源的 [SingleSourceSearcher.search]
///   - 单源超时（默认 15s）→ 该源返回空，不影响其他
///   - 单源抛异常 → 重试 1 次，仍失败则该源返回空
///   - 每个源完成时通过 [onProgress] 回调上报进度
///   - 合并所有结果，按 `dedupKey` 去重，相同 key 的合并 `sources` 列表
///   - 返回 [List<SearchResult>]，按 `sources.length` 倒序（多源覆盖优先）
class SearchAggregator {
  final SingleSourceSearcher searcher;
  final Duration perSourceTimeout;

  /// 并发度：同时发起搜索的书源数量。
  ///
  /// 150+ 书源全并发会同时发起数百个连接，触发操作系统/路由器限流，
  /// 大量请求在 socket 层排队直至超时，表现为"全部源都超时"。
  /// 限流后单批请求能快速完成，整体吞吐反而更高。
  final int concurrency;

  SearchAggregator({
    required this.searcher,
    this.perSourceTimeout = const Duration(seconds: 15),
    this.concurrency = 12,
  });

  /// 搜索并聚合结果。
  ///
  /// [onProgress] 在每个源完成时回调（含超时/失败），用于 UI 展示「3/6 源已返回」。
  Future<List<SearchResult>> search(
    String keyword,
    List<BookSource> sources, {
    void Function(SearchProgress progress)? onProgress,
  }) async {
    final total = sources.length;
    final statusMap = <String, String>{};
    final aggregated = <SearchResult>[];
    var completed = 0;
    var nextIndex = 0;

    void report() {
      onProgress?.call(SearchProgress(
        completed: completed,
        total: total,
        sourceStatus: Map.unmodifiable(statusMap),
        resultCount: aggregated.length,
      ));
    }

    // 固定并发度的 worker 池：每个 worker 循环从队列取下一个源执行，
    // 避免一次性创建 total 个 future 同时发起网络请求。
    Future<void> worker() async {
      while (true) {
        final i = nextIndex++;
        if (i >= total) return;
        final s = sources[i];
        List<SearchResult> list;
        try {
          list = await _searchWithRetry(keyword, s);
          statusMap[s.bookSourceName] = list.isEmpty ? 'empty' : 'ok';
        } catch (_) {
          list = const <SearchResult>[];
          statusMap[s.bookSourceName] = 'error';
        }
        aggregated.addAll(list);
        completed++;
        report();
      }
    }

    final workerCount = concurrency < total ? concurrency : total;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return _mergeAndDedupe(aggregated);
  }

  /// 单源搜索 + 1 次重试。
  ///
  /// 首次失败（超时/异常）时重试一次，应对瞬时网络抖动。
  /// 重试仍失败才视为该源无结果。
  Future<List<SearchResult>> _searchWithRetry(
      String keyword, BookSource s) async {
    try {
      // 不用 onTimeout：让超时抛 TimeoutException 才能触发 catch 重试
      return await searcher.search(keyword, s).timeout(perSourceTimeout);
    } catch (_) {
      // 首次失败（含超时），重试一次
      try {
        return await searcher.search(keyword, s).timeout(perSourceTimeout);
      } catch (_) {
        // 重试仍失败，返回空
        return const [];
      }
    }
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
