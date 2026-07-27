import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/search/search_aggregator.dart';

/// 「已启用书源」仓储抽象。
///
/// 实现会在 Sub-Plan 1E 提供（基于 Drift 的本地数据库）。
/// 此处仅定义接口，让 [SearchBooks] use case 可独立测试。
abstract class BookSourceRepository {
  Future<List<BookSource>> getEnabledSources();
  Future<void> upsert(BookSource source);
  Future<void> deleteByUrl(String bookSourceUrl);

  /// 返回全部书源（含禁用），供管理页使用。
  Future<List<BookSource>> getAll();

  /// 仅切换 [enabled] 字段（不影响其他字段）。
  Future<void> setEnabled(String bookSourceUrl, bool enabled);

  /// 是否存在指定 URL 的书源。
  Future<bool> contains(String bookSourceUrl);

  /// 清空全部书源。
  Future<void> clear();
}

/// 搜索用例：domain 层入口。
///
/// 组合 [SearchAggregator] + [BookSourceRepository]，
/// 给定关键字 → 拉启用书源 → 并发搜索 → 返回去重后的聚合结果。
///
/// 当没有任何启用书源、或所有书源返回空时，返回空列表。
/// UI 层负责展示「未找到」提示（而不是返回假数据混淆用户）。
class SearchBooks {
  final SearchAggregator aggregator;
  final BookSourceRepository repository;

  SearchBooks({
    required this.aggregator,
    required this.repository,
  });

  Future<List<SearchResult>> call(
    String keyword, {
    void Function(SearchProgress)? onProgress,
  }) async {
    final sources = await repository.getEnabledSources();
    if (sources.isEmpty) {
      onProgress?.call(const SearchProgress(
        completed: 0,
        total: 0,
        sourceStatus: {},
        resultCount: 0,
      ));
      return const [];
    }
    return aggregator.search(keyword, sources, onProgress: onProgress);
  }
}
