import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';

/// 「获取书籍详情」用例。
///
/// 入参为搜索结果（含多源）。先从 sources 中选取第一个 enabled 的书源，
/// 拉取其详情页 → 应用 ruleBookInfo → 返回 [BookInfo]。
class GetBookInfo {
  final BookInfoFetcher fetcher;
  final Future<List<BookSource>> Function() _getEnabledSources;

  GetBookInfo({
    required this.fetcher,
    required Future<List<BookSource>> Function() getEnabledSources,
  }) : _getEnabledSources = getEnabledSources;

  Future<BookInfo?> call(SearchResult searchResult) async {
    final sources = await _getEnabledSources();
    final byUrl = {for (final s in sources) s.bookSourceUrl: s};

    for (final src in searchResult.sources) {
      final source = byUrl[src.sourceUrl];
      if (source == null) continue;
      final info = await fetcher.fetch(src.bookUrl, source);
      // 即使部分字段为空也返回（详情页可能没有 name 规则，用搜索结果兜底）
      return info.copyWith(
        name: info.name ?? searchResult.bookName,
        author: info.author ?? searchResult.author,
        coverUrl: info.coverUrl ?? searchResult.coverUrl,
        intro: info.intro ?? searchResult.intro,
        kind: info.kind ?? searchResult.kind,
        wordCount: info.wordCount ?? searchResult.wordCount,
        lastChapter: info.lastChapter ?? searchResult.lastChapter,
      );
    }
    return null;
  }
}

/// 「获取目录」用例。
///
/// 入参为书籍详情。优先用 [BookInfo.tocUrl]，否则回退到 [BookInfo.url]。
class GetToc {
  final TocFetcher fetcher;
  final Future<List<BookSource>> Function() _getEnabledSources;

  GetToc({
    required this.fetcher,
    required Future<List<BookSource>> Function() getEnabledSources,
  }) : _getEnabledSources = getEnabledSources;

  Future<List<Chapter>> call(BookInfo info) async {
    final sources = await _getEnabledSources();
    final byUrl = {for (final s in sources) s.bookSourceUrl: s};
    final source = byUrl[info.sourceUrl];
    if (source == null) return const [];
    final tocUrl = info.tocUrl ?? info.url;
    return fetcher.fetch(tocUrl, source);
  }
}
