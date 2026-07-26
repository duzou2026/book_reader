import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_url_parser.dart';

/// 单源搜索器。
///
/// 对单个 [BookSource] 执行完整搜索流程：
///   1. 用 [SearchUrlParser] 解析 searchUrl（支持 POST / JSON 配置段）
///   2. 调 [DioBookSourceFetcher.fetchWithConfig] 或 [BookSourceFetcher.fetch] 拿响应
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

    // 解析 searchUrl：支持 url,{json} 配置段、POST 请求、@js:url="..." 静态提取
    final config = SearchUrlParser.parse(
      searchUrl,
      keyword: keyword,
      page: 1,
      baseUrl: source.bookSourceUrl,
    );
    if (config == null) {
      // 复杂 @js: 规则等暂不支持，跳过
      return [];
    }

    final String body;
    try {
      // 优先用 fetchWithConfig（支持 POST / charset / 自定义 header）
      if (fetcher is DioBookSourceFetcher) {
        body = await (fetcher as DioBookSourceFetcher)
            .fetchWithConfig(config, source: source);
      } else {
        // 退化为普通 GET（非 Dio 实现时）
        body = await fetcher.fetch(config.url, source: source);
      }
    } catch (_) {
      // 网络失败/超时 → 该源返回空
      return [];
    }

    final bookListRule = rule.bookList;
    if (bookListRule == null) return [];

    // bookList 规则：可能是 CSS / legado 旧式 / XPath / JSON
    final elements = ruleEngine.evalElements(body, bookListRule);

    // JSON 规则的特殊处理：evalElements 对 JSON 返回空，
    // 需要用 evalList 拿字符串列表，再构造结果
    if (elements.isEmpty) {
      return _parseJsonBookList(body, bookListRule, source, rule);
    }

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

  /// JSON bookList 的特殊解析（如 $.data[*] 或 $..book_data[0]&&$.data[*]）。
  ///
  /// JSON 规则无法返回 Element，需要用 evalList 拿到每个 JSON 对象字符串，
  /// 再对每个对象应用 name/bookUrl 等规则（规则也应是 JSONPath）。
  List<SearchResult> _parseJsonBookList(
    String body,
    String bookListRule,
    BookSource source,
    RuleSearch rule,
  ) {
    // 解析整个响应为 JSON
    dynamic jsonData;
    try {
      jsonData = jsonDecode(body);
    } catch (_) {
      return [];
    }
    if (jsonData is! List && jsonData is! Map) return [];

    // 用 JsonPathParser 拿到 book 列表（每个是 Map）
    final items = _extractJsonItems(jsonData, bookListRule);
    if (items.isEmpty) return [];

    final results = <SearchResult>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      // 对每个 JSON 对象，用 JSONPath 规则提取字段
      final itemJson = jsonEncode(item);
      final name = _evalJsonField(itemJson, rule.name);
      final bookUrl = _evalJsonField(itemJson, rule.bookUrl);
      if (name == null || name.isEmpty || bookUrl == null || bookUrl.isEmpty) {
        continue;
      }

      final author = _evalJsonField(itemJson, rule.author) ?? '';
      final coverUrl = _evalJsonField(itemJson, rule.coverUrl);
      final intro = _evalJsonField(itemJson, rule.intro);
      final kind = _evalJsonField(itemJson, rule.kind);
      final wordCount = _evalJsonField(itemJson, rule.wordCount);
      final lastChapter = _evalJsonField(itemJson, rule.lastChapter);

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

  /// 从 JSON 数据中按 bookList 规则提取列表。
  ///
  /// 支持复合规则 `$.a&&$.b`（合并两个 JSONPath 结果）。
  List<dynamic> _extractJsonItems(dynamic jsonData, String rule) {
    // 拆分 && 复合规则
    final parts = rule.split('&&');
    final result = <dynamic>[];
    for (final part in parts) {
      final trimmed = part.trim();
      // 去掉 json: 前缀
      var path = trimmed;
      if (path.startsWith('json:') || path.startsWith('@json:')) {
        path = path.substring(path.indexOf(':') + 1);
      }
      final items = ruleEngine.evalList(jsonEncode(jsonData), path);
      // evalList 返回 List<String>，需要再 parse 回 dynamic
      for (final s in items) {
        try {
          result.add(jsonDecode(s));
        } catch (_) {
          result.add(s);
        }
      }
    }
    return result;
  }

  /// 对 JSON 字符串应用字段规则（通常是 JSONPath）。
  String? _evalJsonField(String json, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.eval(json, rule);
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
