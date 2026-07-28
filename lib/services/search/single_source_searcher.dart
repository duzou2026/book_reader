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

    // 反爬验证页检测：部分站点（如起点）对无 Cookie 请求返回 JS 验证页，
    // 特征是 HTTP 202 + 短响应 + 含 'var buid' 等验证标识。
    // 这种情况下搜索结果必然为空，直接返回避免浪费后续解析时间。
    if (_isAntiCrawlPage(body)) {
      return [];
    }

    final bookListRule = rule.bookList;
    if (bookListRule == null) return [];

    // bookList 规则：可能是 CSS / legado 旧式 / XPath / JSON
    var elements = ruleEngine.evalElements(body, bookListRule);

    // <js> bookList fallback：当 bookList 是 <js> 规则且返回空时，
    // 尝试从 JS 代码中提取 CSS 选择器（如 path='class.res-book-item'），
    // 用它直接从 body 提取元素。很多书源的 <js> bookList 只是包装了
    // 一个 CSS 选择器 + 人机验证逻辑，我们跳过验证逻辑，直接用选择器提取。
    if (elements.isEmpty && _isJsBookListRule(bookListRule)) {
      final fallbackSelector = _extractCssFromJsBookList(bookListRule);
      if (fallbackSelector != null) {
        elements = ruleEngine.evalElements(body, fallbackSelector);
      }
    }

    // JSON 规则的特殊处理：evalElements 对 JSON 返回空，
    // 需要用 evalList 拿字符串列表，再构造结果
    if (elements.isEmpty) {
      return _parseJsonBookList(body, bookListRule, source, rule, keyword);
    }

    final results = <SearchResult>[];
    final keywordNorm = _normalize(keyword);
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

      // 关键字相关性过滤：书名或作者须包含搜索关键字（去空格、不区分大小写）。
      // 部分书源搜索逻辑宽松，会返回与关键字无关的结果（如把关键字当拼音/模糊
      // 匹配返回热门书），导致用户搜「让存在感消失的手链」却搜出同名无关的
      // 1024 章小说。这里做一道兜底过滤，避免明显不相关的结果污染列表。
      if (!_isRelevant(name, author, keywordNorm)) {
        continue;
      }

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
    String keyword,
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
    final keywordNorm = _normalize(keyword);
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

      // 关键字相关性过滤（与 Element 路径一致）
      if (!_isRelevant(name, author, keywordNorm)) {
        continue;
      }

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
        dynamic decoded;
        try {
          decoded = jsonDecode(s);
        } catch (_) {
          decoded = s;
        }
        // $.data 这种不带 [*] 的路径会返回整个数组的 JSON 字符串，
        // 需要展开为各个元素；$.data[*] 则已经是逐个元素，无需展开。
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

  String? _evalField(element, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.evalOnElement(element, rule);
  }

  /// 归一化字符串：去前后空白、压缩内部连续空白、转小写。
  /// 用于关键字与书名/作者做包含判断前的统一处理。
  static String _normalize(String s) {
    return s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 判断搜索结果是否与关键字相关。
  ///
  /// 规则：归一化后的「书名」或「作者」任一包含归一化后的关键字即视为相关。
  /// 这样既能过滤掉书源返回的无关热门书，又不会误伤「按作者搜」的场景。
  /// 关键字为空（理论上不会发生）时一律放行，避免把所有结果都过滤掉。
  static bool _isRelevant(String name, String author, String keywordNorm) {
    if (keywordNorm.isEmpty) return true;
    final n = _normalize(name);
    if (n.contains(keywordNorm)) return true;
    final a = _normalize(author);
    if (a.contains(keywordNorm)) return true;
    return false;
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

  /// 检测响应是否为反爬验证页。
  ///
  /// 特征：短响应（<2KB）+ 含 JS 验证标识（'var buid' / 'verify' / 'blocked'）。
  /// 起点等站点对无 Cookie 请求返回 HTTP 202 + 209 字节的 JS 验证页，
  /// 而非真正的搜索结果 HTML。
  static final _antiCrawlPatterns = [
    RegExp(r'var\s+buid'),
    RegExp(r'<title>\s*(验证|blocked|verify|安全验证)', caseSensitive: false),
  ];

  bool _isAntiCrawlPage(String body) {
    // 反爬验证页通常很短（< 2KB），真搜索结果一般 > 10KB
    if (body.length > 2048) return false;
    for (final p in _antiCrawlPatterns) {
      if (p.hasMatch(body)) return true;
    }
    return false;
  }

  /// 判断 bookList 规则是否为 `<js>` 规则。
  bool _isJsBookListRule(String rule) {
    final trimmed = rule.trim();
    return trimmed.startsWith('<js>') || trimmed.startsWith('@js:');
  }

  /// 从 `<js>` bookList 规则中提取 CSS 选择器作为 fallback。
  ///
  /// 很多书源的 `<js>` bookList 只是包装了一个 CSS 选择器 + 人机验证逻辑，
  /// 例如起点的规则：
  /// ```js
  /// <js>
  /// path='class.res-book-item';
  /// u=java.get('url');
  /// c=java.getElement(path);
  /// ...
  /// </js>
  /// ```
  /// 这里提取 `path='...'` 中的选择器，跳过人机验证逻辑直接用它提取元素。
  static final _pathVarPattern = RegExp(r'''path\s*=\s*['"]([^'"]+)['"]''');

  String? _extractCssFromJsBookList(String rule) {
    final match = _pathVarPattern.firstMatch(rule);
    return match?.group(1);
  }
}
