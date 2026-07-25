import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 书籍详情抓取器。
///
/// 对单个 [BookSource] 的书籍详情页应用 `RuleBookInfo` 解析字段。
/// 详情页 URL 来自搜索结果中的 `bookUrl`。
class BookInfoFetcher {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;

  BookInfoFetcher({required this.fetcher, required this.ruleEngine});

  Future<BookInfo> fetch(String bookUrl, BookSource source) async {
    final rule = source.ruleBookInfo;
    final String body;
    try {
      body = await fetcher.fetch(bookUrl, source: source);
    } catch (_) {
      return BookInfo(
        url: bookUrl,
        sourceName: source.bookSourceName,
        sourceUrl: source.bookSourceUrl,
      );
    }

    // 如果书源没有定义 ruleBookInfo，则只能返回 URL 等已知信息
    if (rule == null) {
      return BookInfo(
        url: bookUrl,
        sourceName: source.bookSourceName,
        sourceUrl: source.bookSourceUrl,
      );
    }

    final name = _eval(body, rule.name);
    final author = _eval(body, rule.author);
    final intro = _eval(body, rule.intro);
    final coverUrl = _eval(body, rule.coverUrl);
    final kind = _eval(body, rule.kind);
    final wordCount = _eval(body, rule.wordCount);
    final lastChapter = _eval(body, rule.lastChapter);
    final tocUrl = _eval(body, rule.tocUrl);

    final absoluteCoverUrl =
        coverUrl == null ? null : _resolveUrl(coverUrl, source.bookSourceUrl);
    final absoluteTocUrl =
        tocUrl == null ? null : _resolveUrl(tocUrl, source.bookSourceUrl);

    return BookInfo(
      url: bookUrl,
      sourceName: source.bookSourceName,
      sourceUrl: source.bookSourceUrl,
      name: name?.trim(),
      author: author?.trim(),
      intro: intro?.trim(),
      coverUrl: absoluteCoverUrl,
      kind: kind?.trim(),
      wordCount: wordCount?.trim(),
      lastChapter: lastChapter?.trim(),
      tocUrl: absoluteTocUrl ?? bookUrl,
    );
  }

  String? _eval(String html, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.eval(html, rule);
  }

  String _resolveUrl(String url, String baseUrl) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) return 'http:$trimmed';
    try {
      final base = Uri.parse(baseUrl);
      if (trimmed.startsWith('/')) {
        return '${base.scheme}://${base.host}$trimmed';
      }
      final baseDir =
          base.path.substring(0, base.path.lastIndexOf('/') + 1);
      return '${base.scheme}://${base.host}$baseDir$trimmed';
    } catch (_) {
      return trimmed;
    }
  }
}
