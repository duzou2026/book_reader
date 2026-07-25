import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';

/// 「获取章节正文」用例。
///
/// 入参为 [BookInfo] + [Chapter]，根据 info.sourceUrl 找到对应 BookSource，
/// 调 [ContentFetcher] 抓取章节正文。
class GetChapterContent {
  final ContentFetcher fetcher;
  final Future<List<BookSource>> Function() _getEnabledSources;

  GetChapterContent({
    required this.fetcher,
    required Future<List<BookSource>> Function() getEnabledSources,
  }) : _getEnabledSources = getEnabledSources;

  Future<String> call(BookInfo info, Chapter chapter) async {
    final sources = await _getEnabledSources();
    final byUrl = {for (final s in sources) s.bookSourceUrl: s};
    final source = byUrl[info.sourceUrl];
    if (source == null) return '';
    return fetcher.fetch(chapter.url, source);
  }
}
