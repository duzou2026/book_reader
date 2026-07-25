import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/search/search_aggregator.dart';

/// 「发现/排行」用例。
///
/// 由于 legado 书源并不统一暴露 discoverUrl，本用例采用通用方案：
///   - 按 [DiscoverCategory] 预设关键词，用 [SearchAggregator] 多源聚合搜索
///   - 返回的 [SearchResult] 已按 `sources.length` 倒序：多源覆盖即视为热度信号
///   - 单次请求限制返回前 N 条，避免列表过长
class DiscoverBooks {
  final SearchAggregator _aggregator;
  final Future<List<BookSource>> Function() _getEnabledSources;

  DiscoverBooks({
    required SearchAggregator aggregator,
    required Future<List<BookSource>> Function() getEnabledSources,
  })  : _aggregator = aggregator,
        _getEnabledSources = getEnabledSources;

  /// 拉取某分类下的榜单。
  ///
  /// [onProgress] 透传给 [SearchAggregator.search]，用于 UI 展示源完成进度。
  Future<List<SearchResult>> fetch(
    DiscoverCategory category, {
    int limit = 30,
    void Function(SearchProgress progress)? onProgress,
  }) async {
    final sources = await _getEnabledSources();
    if (sources.isEmpty) return const [];
    final all = <SearchResult>[];
    // 多关键词轮询：取每个关键词的前若干条，组合后再次去重排序
    for (final kw in category.keywords) {
      final list = await _aggregator.search(kw, sources, onProgress: onProgress);
      all.addAll(list);
      if (all.length >= limit * 2) break;
    }
    // 合并去重
    final merged = _mergeAndDedupe(all);
    return merged.take(limit).toList();
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

/// 发现分类：名称 + 关键词列表。
class DiscoverCategory {
  final String id;
  final String name;
  final String emoji;
  final List<String> keywords;

  const DiscoverCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.keywords,
  });
}

/// 内置发现分类。
///
/// 关键词选用搜索量大、覆盖广的常见词，避免冷僻词导致空结果。
class DiscoverCategories {
  static const List<DiscoverCategory> all = [
    DiscoverCategory(
      id: 'hot',
      name: '热门',
      emoji: '🔥',
      keywords: ['玄幻', '都市', '言情', '穿越'],
    ),
    DiscoverCategory(
      id: 'male',
      name: '男生',
      emoji: '♂️',
      keywords: ['玄幻', '武侠', '科幻', '历史'],
    ),
    DiscoverCategory(
      id: 'female',
      name: '女生',
      emoji: '♀️',
      keywords: ['言情', '穿越', '校园', '总裁'],
    ),
    DiscoverCategory(
      id: 'xuanhuan',
      name: '玄幻',
      emoji: '⚡',
      keywords: ['玄幻', '修真', '仙侠', '魔法'],
    ),
    DiscoverCategory(
      id: 'dushi',
      name: '都市',
      emoji: '🏙️',
      keywords: ['都市', '职场', '商战', '生活'],
    ),
    DiscoverCategory(
      id: 'kehuan',
      name: '科幻',
      emoji: '🚀',
      keywords: ['科幻', '末世', '星际', '机甲'],
    ),
    DiscoverCategory(
      id: 'lishi',
      name: '历史',
      emoji: '📜',
      keywords: ['历史', '三国', '明朝', '清朝'],
    ),
    DiscoverCategory(
      id: 'lingyi',
      name: '灵异',
      emoji: '👻',
      keywords: ['灵异', '恐怖', '悬疑', '盗墓'],
    ),
  ];
}
