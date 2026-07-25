import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/content_purifier.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 章节正文抓取器。
///
/// 对书源章节页应用 `RuleContent` 解析正文。
/// 支持分页正文：若 `nextContentUrl` 规则求值得到非空 URL，则继续抓取下一页，
/// 拼接所有页的正文，直到无 nextContentUrl 或达到 [maxPages] 上限。
class ContentFetcher {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;

  static const maxPages = 50;

  ContentFetcher({required this.fetcher, required this.ruleEngine});

  Future<String> fetch(String chapterUrl, BookSource source) async {
    final rule = source.ruleContent;
    if (rule == null) return '';

    final parts = <String>[];
    var currentUrl = chapterUrl;
    var pageIndex = 0;

    while (currentUrl.isNotEmpty && pageIndex < maxPages) {
      final String body;
      try {
        body = await fetcher.fetch(currentUrl, source: source);
      } catch (_) {
        break;
      }

      final contentRule = rule.content;
      if (contentRule == null || contentRule.isEmpty) break;

      final piece = ruleEngine.eval(body, contentRule);
      if (piece != null && piece.trim().isNotEmpty) {
        parts.add(piece.trim());
      }

      // 多页：求值 nextContentUrl
      final nextRule = rule.nextContentUrl;
      if (nextRule == null || nextRule.isEmpty) break;
      final nextRaw = ruleEngine.eval(body, nextRule);
      if (nextRaw == null || nextRaw.trim().isEmpty) break;
      final nextAbsolute =
          _resolveUrl(nextRaw.trim(), source.bookSourceUrl);
      if (nextAbsolute == currentUrl) break; // 防死循环
      currentUrl = nextAbsolute;
      pageIndex++;
    }

    var combined = parts.join('\n\n');

    // 应用净化规则
    final replaceRegex = rule.replaceRegex;
    if (replaceRegex != null && replaceRegex.isNotEmpty) {
      combined = _applyReplaceRegex(combined, replaceRegex);
    }

    return combined;
  }

  /// 应用净化规则。
  ///
  /// 支持 legado 语法：
  ///   - `regex` → 替换为空
  ///   - `regex##replacement` → 替换为 replacement
  ///   - 多条规则用 `||` 或 `\n` 分隔
  ///   - 替换串中可引用捕获组：`$1`、`$2`、`$<name>`
  ///   - 正则内联 flag：`(?i)xxx`、`(?s:.)`（Dart RegExp 原生支持）
  ///
  /// 示例：
  ///   `广告.*?\n` → 删除「广告」所在整行
  ///   `(http[^\\s]+)##<a href="$1">$1</a>` → URL 转超链接
  ///   `(?i)ERROR` → 删除 ERROR / error / Error（大小写不敏感）
  String _applyReplaceRegex(String content, String replaceRegex) {
    return ContentPurifier.purify(content, replaceRegex);
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
