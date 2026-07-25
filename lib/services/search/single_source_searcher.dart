import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_context.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 单源搜索器。
///
/// 对单个 [BookSource] 执行完整搜索流程：
///   1. 用 [RuleContext] 替换 `searchUrl` 里的 `{{key}}`
///   2. 调 [BookSourceFetcher.fetch] 拿响应
///   3. 用 [RuleEngine.evalElements] 应用 `ruleSearch.bookList` 拿 book 节点列表
///   4. 对每个节点，应用 `ruleSearch.name/author/coverUrl/intro/bookUrl` 等
///   5. 拼接 `bookUrl` 为绝对 URL
///   6. 返回 [List<SearchResult>]，每个含一个 [SearchSource]
class SingleSourceSearcher {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;

  SingleSourceSearcher({
    required this.fetcher,
    required this.ruleEngine,
  });

  Future<List<SearchResult>> search(String keyword, BookSource source) async {
    final searchUrl = source.searchUrl;
    final rule = source.ruleSearch;
    if (searchUrl == null || rule == null) return [];

    final ctx = RuleContext(keyword: keyword, page: 1);
    final url = ctx.substitute(searchUrl);

    final String body;
    try {
      body = await fetcher.fetch(url, source: source);
    } catch (_) {
      // 网络失败/超时 → 该源返回空
      return [];
    }

    final bookListRule = rule.bookList;
    if (bookListRule == null) return [];

    // bookList 通常是 CSS 规则，返回 Element 列表
    final elements = ruleEngine.evalElements(body, bookListRule);

    final results = <SearchResult>[];
    for (final element in elements) {
      final name = _evalField(element, rule.name);
      final bookUrl = _evalField(element, rule.bookUrl);
      if (name == null || name.isEmpty || bookUrl == null || bookUrl.isEmpty) {
        continue;
      }

      final author = _evalField(element, rule.author) ?? '';
      final coverUrl = _evalField(element, rule.coverUrl);
      final intro = _evalField(element, rule.intro);
      final kind = _evalField(element, rule.kind);
      final wordCount = _evalField(element, rule.wordCount);
      final lastChapter = _evalField(element, rule.lastChapter);

      final absoluteBookUrl = _resolveUrl(bookUrl, source.bookSourceUrl);
      final absoluteCoverUrl =
          coverUrl == null ? null : _resolveUrl(coverUrl, source.bookSourceUrl);

      results.add(SearchResult(
        bookName: name.trim(),
        author: author.trim(),
        coverUrl: absoluteCoverUrl,
        intro: intro?.trim(),
        kind: kind?.trim(),
        wordCount: wordCount?.trim(),
        lastChapter: lastChapter?.trim(),
        sources: [
          SearchSource(
            sourceName: source.bookSourceName,
            sourceUrl: source.bookSourceUrl,
            bookUrl: absoluteBookUrl,
          ),
        ],
      ));
    }
    return results;
  }

  String? _evalField(element, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.evalOnElement(element, rule);
  }

  /// 把相对 URL 解析为绝对 URL。
  /// - 已经是绝对 URL（http/https 开头）→ 原样返回
  /// - 以 `//` 开头 → 加 http:（罕见，部分老站）
  /// - 以 `/` 开头 → 拼到 baseUrl 的 scheme://host
  /// - 其他 → 拼到 baseUrl 的目录
  String _resolveUrl(String url, String baseUrl) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'http:$trimmed';
    }

    try {
      final base = Uri.parse(baseUrl);
      if (trimmed.startsWith('/')) {
        return '${base.scheme}://${base.host}$trimmed';
      }
      // 相对路径：拼到 base 的目录
      final baseDir = base.path.substring(0, base.path.lastIndexOf('/') + 1);
      return '${base.scheme}://${base.host}$baseDir$trimmed';
    } catch (_) {
      return trimmed;
    }
  }
}
