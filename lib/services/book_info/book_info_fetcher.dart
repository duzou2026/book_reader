import 'dart:convert';

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

    // JSON 详情页的 init 语义兜底：
    // legado 书源里 ruleBookInfo 常带 `init: $.data`，表示把 `data` 字段
    // 解包为后续规则的上下文。我们没在 model 里建模 init 字段，这里做
    // 启发式兜底——如果用完整 body 拿不到 name/author，且 body 是 JSON
    // 且含 `data`/`result` 这类 Map 包装字段，就用包装字段的内容重试。
    var ctx = body;
    final name0 = _eval(ctx, rule.name);
    final author0 = _eval(ctx, rule.author);
    if ((name0 == null || name0.isEmpty) &&
        (author0 == null || author0.isEmpty)) {
      final unwrapped = _unwrapJsonBody(body);
      if (unwrapped != null) ctx = unwrapped;
    }

    final name = name0 ?? _eval(ctx, rule.name);
    final author = author0 ?? _eval(ctx, rule.author);
    final intro = _eval(ctx, rule.intro);
    final coverUrl = _eval(ctx, rule.coverUrl);
    final kind = _eval(ctx, rule.kind);
    final wordCount = _eval(ctx, rule.wordCount);
    final lastChapter = _eval(ctx, rule.lastChapter);
    final tocUrl = _eval(ctx, rule.tocUrl);

    final absoluteCoverUrl =
        coverUrl == null ? null : _resolveUrl(coverUrl, source.bookSourceUrl);
    final absoluteTocUrl =
        tocUrl == null ? null : _resolveUrl(tocUrl, source.bookSourceUrl);

    // 字段清洗：剥离规则残留（@js: 规则文本、$1 占位符、<js> 标签等）。
    // 书源规则执行失败或 legado @js: 后缀未支持时，
    // 规则字符串可能泄露到字段值里，这里做兜底清洗。
    return BookInfo(
      url: bookUrl,
      sourceName: source.bookSourceName,
      sourceUrl: source.bookSourceUrl,
      name: _cleanField(name),
      author: _cleanField(author),
      intro: _cleanField(intro),
      coverUrl: absoluteCoverUrl,
      kind: _cleanField(kind),
      wordCount: _cleanField(wordCount),
      lastChapter: _cleanField(lastChapter),
      tocUrl: absoluteTocUrl ?? bookUrl,
    );
  }

  /// 清洗字段值：剥离规则残留和未展开占位符。
  ///
  /// 处理内容：
  ///   - `@js:...` / `@get:...` / `@put:...` / `@post:...` 规则文本
  ///   - `<js>...</js>` 块
  ///   - `$1`、`$2` 等未展开的捕获组占位符
  ///   - 合并多余空行、首尾空白
  /// 清洗后为空则返回 null。
  String? _cleanField(String? value) {
    if (value == null) return null;
    var s = value;
    // 剥离 @js: / @get: / @put: / @post: 规则文本（到行尾）
    s = s.replaceAll(RegExp(r'@(?:js|get|put|post):[^\n]*'), '');
    // 剥离 <js>...</js> 块
    s = s.replaceAll(RegExp(r'<js>.*?</js>', dotAll: true), '');
    // 剥离未展开的 $1 / $2 等占位符
    s = s.replaceAll(RegExp(r'\$\d+'), '');
    // 合并多余空行
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    s = s.trim();
    return s.isEmpty ? null : s;
  }

  /// 尝试把 JSON 响应的包装字段（`data` / `result`）解包为内层对象。
  ///
  /// 用于模拟 legado `init: $.data` 语义：很多 JSON API 返回
  /// `{"code":200,"data":{...实际字段...}}`，而书源规则是 `$.title` 而非
  /// `$.data.title`。解包后规则的根就变成了 `data` 对象。
  ///
  /// 仅当 `data`/`result` 是 Map 时才解包；是 List 时由 chapterList 处理。
  /// 非 JSON 或无包装字段时返回 null。
  String? _unwrapJsonBody(String body) {
    final trimmed = body.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      final root = jsonDecode(trimmed);
      if (root is! Map) return null;
      for (final key in const ['data', 'result']) {
        final v = root[key];
        if (v is Map<String, dynamic>) {
          return jsonEncode(v);
        }
      }
    } catch (_) {}
    return null;
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
