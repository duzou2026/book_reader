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
}

/// 搜索用例：domain 层入口。
///
/// 组合 [SearchAggregator] + [BookSourceRepository]，
/// 给定关键字 → 拉启用书源 → 并发搜索 → 返回去重后的聚合结果。
class SearchBooks {
  final SearchAggregator aggregator;
  final BookSourceRepository repository;

  SearchBooks({required this.aggregator, required this.repository});

  Future<List<SearchResult>> call(String keyword) async {
    final sources = await repository.getEnabledSources();
    if (sources.isEmpty) return const [];
    return aggregator.search(keyword, sources);
  }
}
