import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/explore/explore_url_parser.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 书源分类浏览用例。
///
/// 类似 legado App 的「发现」功能：直接进入某个书源，按分类浏览该源内的书。
///
/// 流程：
///   1. [getCategories] 用 [ExploreUrlParser] 解析书源的 `exploreUrl`，得到分类列表
///   2. [fetchCategory] 抓取某分类某页的书籍列表：
///      - 用 [ExploreUrlParser.buildUrl] 拼接绝对 URL（替换 `{{page}}`）
///      - 用 [DioBookSourceFetcher.fetchWithConfig] / [BookSourceFetcher.fetch] 抓取
///      - 用 [RuleEngine.evalElements] 应用 `ruleExplore.bookList` 提取书籍节点
///      - 逐节点提取 name/bookUrl/author/coverUrl/intro/kind 等字段
///      - JSON bookList 规则的 fallback：evalElements 返回空时尝试 jsonDecode + JSONPath
///      - 构造 [List<SearchResult>]，每个含一个 [SearchSource]
///
/// 解析逻辑参考 [SingleSourceSearcher]，由于那边的 `_evalField`/`_resolveUrl`
/// 等是 private，这里重新实现简版（不改动 single_source_searcher）。
class ExploreBooks {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;

  ExploreBooks({
    required this.fetcher,
    required this.ruleEngine,
  });

  /// 解析书源的 exploreUrl，返回分类列表。
  ///
  /// 若书源没有 exploreUrl 或 ruleExplore.bookList，返回空列表。
  List<ExploreCategory> getCategories(BookSource source) {
    final rule = source.ruleExplore;
    if (source.exploreUrl == null ||
        source.exploreUrl!.trim().isEmpty ||
        rule == null ||
        rule.bookList == null ||
        rule.bookList!.trim().isEmpty) {
      return [];
    }
    return ExploreUrlParser.parse(source.exploreUrl);
  }

  /// 抓取某分类某页的书籍列表。
  ///
  /// [page] 从 1 开始。网络失败/解析无结果时返回空列表。
  Future<List<SearchResult>> fetchCategory(
    BookSource source,
    ExploreCategory category, {
    int page = 1,
  }) async {
    final rule = source.ruleExplore;
    final bookListRule = rule?.bookList;
    if (bookListRule == null || bookListRule.trim().isEmpty) return [];
    if (category.isHeader) return [];

    // 拼接绝对 URL（替换 {{page}}）
    final url = ExploreUrlParser.buildUrl(category, page, source.bookSourceUrl);

    // 抓取响应
    final String body;
    try {
      if (fetcher is DioBookSourceFetcher) {
        // 发现页分类通常是简单 GET，构造 GET 的 RequestConfig
        body = await (fetcher as DioBookSourceFetcher).fetchWithConfig(
          RequestConfig(url: url, method: 'GET'),
          source: source,
        );
      } else {
        body = await fetcher.fetch(url, source: source);
      }
    } catch (_) {
      // 网络失败/超时 → 返回空
      return [];
    }

    // 提取书籍节点列表
    var elements = ruleEngine.evalElements(body, bookListRule);

    if (elements.isEmpty) {
      // JSON bookList fallback：evalElements 对 JSON 返回空，
      // 尝试 jsonDecode + JSONPath 提取
      final jsonResults = _parseJsonBookList(body, bookListRule, source, rule!);
      return jsonResults;
    }

    final results = <SearchResult>[];
    for (final element in elements) {
      final name = _evalField(element, rule!.name);
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

  /// JSON bookList 的特殊解析（如 $.data[*]）。
  ///
  /// JSON 规则无法返回 Element，需要用 evalList 拿到每个 JSON 对象字符串，
  /// 再对每个对象应用 name/bookUrl 等规则（规则也应是 JSONPath）。
  List<SearchResult> _parseJsonBookList(
    String body,
    String bookListRule,
    BookSource source,
    RuleSearch rule,
  ) {
    dynamic jsonData;
    try {
      jsonData = jsonDecode(body);
    } catch (_) {
      return [];
    }
    if (jsonData is! List && jsonData is! Map) return [];

    final items = _extractJsonItems(jsonData, bookListRule);
    if (items.isEmpty) return [];

    final results = <SearchResult>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
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
    final parts = rule.split('&&');
    final result = <dynamic>[];
    for (final part in parts) {
      final trimmed = part.trim();
      var path = trimmed;
      // 去掉 json: 前缀
      if (path.startsWith('json:') || path.startsWith('@json:')) {
        path = path.substring(path.indexOf(':') + 1);
      }
      final items = ruleEngine.evalList(jsonEncode(jsonData), path);
      for (final s in items) {
        dynamic decoded;
        try {
          decoded = jsonDecode(s);
        } catch (_) {
          decoded = s;
        }
        if (decoded is List) {
          result.addAll(decoded);
        } else {
          result.add(decoded);
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

  /// 在已选定的 Element 上应用规则。
  String? _evalField(element, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.evalOnElement(element, rule);
  }

  /// 把相对 URL 解析为绝对 URL。
  /// - 已经是绝对 URL（http/https 开头）→ 原样返回
  /// - 以 `//` 开头 → 加 https:
  /// - 以 `/` 开头 → 拼到 baseUrl 的 scheme://host
  /// - 其他 → 拼到 baseUrl 的目录
  String _resolveUrl(String url, String baseUrl) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
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
