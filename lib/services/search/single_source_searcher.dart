import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_url_parser.dart';
import 'package:flutter/foundation.dart';

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
    if (searchUrl == null || rule == null) {
      debugPrint('[搜索] ${source.bookSourceName}: 无 searchUrl 或 ruleSearch，跳过');
      return [];
    }

    // 解析 searchUrl：支持 url,{json} 配置段、POST 请求、@js:url="..." 静态提取
    final config = SearchUrlParser.parse(
      searchUrl,
      keyword: keyword,
      page: 1,
      baseUrl: source.bookSourceUrl,
    );
    if (config == null) {
      debugPrint('[搜索] ${source.bookSourceName}: searchUrl 解析失败，跳过');
      return [];
    }
    debugPrint('[搜索] ${source.bookSourceName}: URL=${config.url}, method=${config.method}, body=${config.body}, charset=${config.charset}');

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
    } catch (e) {
      debugPrint('[搜索] ${source.bookSourceName}: 请求失败: $e');
      return [];
    }
    debugPrint('[搜索] ${source.bookSourceName}: 响应长度=${body.length}');

    // 反爬验证页检测：部分站点（如起点）对无 Cookie 请求返回 JS 验证页，
    // 特征是 HTTP 202 + 短响应 + 含 'var buid' 等验证标识。
    // 这种情况下搜索结果必然为空，直接返回避免浪费后续解析时间。
    if (_isAntiCrawlPage(body)) {
      debugPrint('[搜索] ${source.bookSourceName}: 检测到反爬验证页，跳过');
      return [];
    }

    final bookListRule = rule.bookList;
    if (bookListRule == null) return [];

    // bookList 规则：可能是 CSS / legado 旧式 / XPath / JSON
    var elements = ruleEngine.evalElements(body, bookListRule);
    debugPrint('[搜索] ${source.bookSourceName}: bookList=$bookListRule, 匹配元素数=${elements.length}');

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
      final jsonResults = _parseJsonBookList(body, bookListRule, source, rule, keyword);
      if (jsonResults.isNotEmpty) return jsonResults;

      // 唯一搜索结果 302 跳转 fallback：
      // 部分站点（如桃桃书）搜索只有一本书时直接 302 跳转到详情页，
      // dio 跟随重定向后拿到详情页 HTML，bookList 选择器匹配不到列表项。
      // 检查是否是详情页（有 og:novel:book_name），从 og meta 构造单条结果。
      return _tryParseAsDetailPage(body, source, keyword);
    }

    final results = <SearchResult>[];
    final keywordNorm = _normalize(keyword);
    debugPrint('[搜索] ${source.bookSourceName}: 关键词归一化=$keywordNorm');
    for (final element in elements) {
      final name = _evalField(element, rule.name);
      final bookUrl = _evalField(element, rule.bookUrl);
      if (name == null || name.isEmpty || bookUrl == null || bookUrl.isEmpty) {
        debugPrint('[搜索] ${source.bookSourceName}: 跳过空名称/链接的结果 name=$name, bookUrl=$bookUrl');
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
      final relevant = _isRelevant(name, author, keywordNorm);
      if (!relevant) {
        debugPrint('[搜索] ${source.bookSourceName}: 相关性过滤排除 name=$name, author=$author');
        continue;
      }
      debugPrint('[搜索] ${source.bookSourceName}: 匹配结果 name=$name, author=$author, bookUrl=$bookUrl');

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

  /// 唯一搜索结果 302 跳转 fallback：检查响应是否是详情页。
  ///
  /// 部分站点（如桃桃书）搜索唯一匹配时直接 302 跳转到书籍详情页，
  /// dio 跟随重定向后拿到的是详情页 HTML 而非搜索列表页，bookList
  /// 选择器匹配不到任何元素。此时检查页面是否有 og:novel:book_name
  /// meta 标签，如果有则从 og meta 提取书名/作者/URL，构造单条搜索结果。
  ///
  /// 这种 fallback 是通用的——任何使用 og meta 标签的"唯一结果跳转"站点
  /// 都能受益，不限于桃桃书。
  List<SearchResult> _tryParseAsDetailPage(
    String body,
    BookSource source,
    String keyword,
  ) {
    // 用 XPath 从 og meta 标签提取书名
    final name = ruleEngine.eval(body, "//meta[@property='og:novel:book_name']/@content");
    if (name == null || name.trim().isEmpty) return [];

    final author = ruleEngine.eval(body, "//meta[@property='og:novel:author']/@content") ?? '';
    final coverUrl = ruleEngine.eval(body, "//meta[@property='og:image']/@content");
    final intro = ruleEngine.eval(body, "//meta[@property='og:description']/@content");
    // og:novel:read_url 是详情页 URL（书籍 URL）
    final bookUrl = ruleEngine.eval(body, "//meta[@property='og:novel:read_url']/@content");

    // 如果没有 read_url，用书源 URL 兜底（无法定位书籍，跳过）
    if (bookUrl == null || bookUrl.trim().isEmpty) return [];

    // 关键字相关性过滤
    final keywordNorm = _normalize(keyword);
    if (!_isRelevant(name, author, keywordNorm)) return [];

    final absoluteBookUrl = _resolveUrl(bookUrl, source.bookSourceUrl);
    final absoluteCoverUrl =
        coverUrl == null ? null : _resolveUrl(coverUrl, source.bookSourceUrl);

    return [
      SearchResult(
        bookName: name.trim(),
        author: author.trim(),
        coverUrl: absoluteCoverUrl,
        intro: intro?.trim(),
        sources: [
          SearchSource(
            sourceName: source.bookSourceName,
            sourceUrl: source.bookSourceUrl,
            bookUrl: absoluteBookUrl,
          ),
        ],
      ),
    ];
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

  /// 归一化字符串：去前后空白、压缩内部连续空白、转小写、去常见标点。
  ///
  /// 去除的标点包括书名号《》、引号、冒号、中英文标点等，
  /// 让"《三体》"能匹配关键字"三体"，"三体：地球往事"能匹配"三体"。
  /// 仍保留字母数字和中文，避免过度模糊导致误匹配。
  static String _normalize(String s) {
    return s
        .toLowerCase()
        .trim()
        // 去除书名号、引号、括号、冒号、破折号等常见装饰性标点
        .replaceAll(RegExp(r'[\u300a\u300b\u3001\u3002\uff08\uff09\u201c\u201d\u2018\u2019\uff1a\uff1b\u2014\u2026\u2015:;,\(\)\[\]【】《》「」『』]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 判断搜索结果是否与关键字相关。
  ///
  /// 规则（宽松双向匹配）：
  ///   1. 归一化后「书名」包含关键字 或 关键字包含书名 → 相关
  ///      （覆盖"斗破苍穹（全本）"搜"斗破苍穹"、"斗破苍穹"搜"斗破苍穹（全本）"）
  ///   2. 「作者」包含关键字 → 相关（按作者搜场景）
  ///   3. 关键字为空 → 放行
  ///
  /// 之前只做单向 `name.contains(keyword)`，书源返回带前缀/后缀的书名
  /// （如"斗破苍穹全文阅读"、"最新章节：斗破苍穹"）时把正常结果误过滤，
  /// 是"好多书搜不出来"的主因之一。
  static bool _isRelevant(String name, String author, String keywordNorm) {
    if (keywordNorm.isEmpty) return true;
    final n = _normalize(name);
    if (n.isNotEmpty && (n.contains(keywordNorm) || keywordNorm.contains(n))) {
      return true;
    }
    final a = _normalize(author);
    if (a.isNotEmpty && a.contains(keywordNorm)) return true;
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
  /// 起点等站点对无 Cookie 请求返回 JS 验证页，Cloudflare/5秒盾等
  /// 也会返回验证页。命中任一特征即视为无效搜索响应。
  static final _antiCrawlPatterns = [
    RegExp(r'var\s+buid'),
    RegExp(r'<title>\s*(验证|blocked|verify|安全验证)', caseSensitive: false),
    // Cloudflare 5秒盾 / 挑战页
    RegExp(r'challenges\.cloudflare\.com', caseSensitive: false),
    RegExp(r'cloudflare-static', caseSensitive: false),
    RegExp(r'_cf_chl_opt', caseSensitive: false),
    RegExp(r'cf-turnstile', caseSensitive: false),
    // 5秒盾
    RegExp(r'5\s*秒.*盾', caseSensitive: false),
    RegExp(r'shield\.js', caseSensitive: false),
    // CAPTCHA
    RegExp(r'google\.com/recaptcha', caseSensitive: false),
    RegExp(r'hcaptcha\.com', caseSensitive: false),
    // 503 / 不可用
    RegExp(r'<title>\s*503', caseSensitive: false),
    RegExp(r'service\s*unavailable', caseSensitive: false),
  ];

  bool _isAntiCrawlPage(String body) {
    // 前 4KB 通常包含 title / script 等验证特征，避免扫描整页大响应
    final head = body.length > 4096 ? body.substring(0, 4096) : body;
    for (final p in _antiCrawlPatterns) {
      if (p.hasMatch(head)) return true;
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
