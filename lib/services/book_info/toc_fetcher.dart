import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 目录抓取器。
///
/// 对书源目录页应用 `RuleToc` 解析章节列表。
/// 支持多页目录：若 `nextTocUrl` 规则求值得到非空 URL，则继续抓取下一页，
/// 直到无 nextTocUrl 或达到 [maxPages] 上限。
class TocFetcher {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;

  /// 最多抓取的目录页数，防止无限分页。
  static const maxPages = 50;

  TocFetcher({required this.fetcher, required this.ruleEngine});

  Future<List<Chapter>> fetch(String tocUrl, BookSource source) async {
    final rule = source.ruleToc;
    if (rule == null) return const [];

    final chapters = <Chapter>[];
    var currentUrl = tocUrl;
    var pageIndex = 0;

    while (currentUrl.isNotEmpty && pageIndex < maxPages) {
      final String body;
      try {
        body = await fetcher.fetch(currentUrl, source: source);
      } catch (_) {
        break;
      }

      final chapterListRule = rule.chapterList;
      if (chapterListRule == null || chapterListRule.isEmpty) break;

      final elements = ruleEngine.evalElements(body, chapterListRule);

      final baseIndex = chapters.length;
      for (var i = 0; i < elements.length; i++) {
        final element = elements[i];
        final name = _evalOnElement(element, rule.chapterName);
        final url = _evalOnElement(element, rule.chapterUrl);
        if (name == null || name.isEmpty || url == null || url.isEmpty) {
          continue;
        }
        final isVolume = _evalOnElement(element, rule.isVolume) == 'true' ||
            _evalOnElement(element, rule.isVolume) == '1';
        final isVip = _evalOnElement(element, rule.isVip) == 'true' ||
            _evalOnElement(element, rule.isVip) == '1';
        final updateTime = _evalOnElement(element, rule.updateTime);

        final absoluteUrl = _resolveUrl(url, source.bookSourceUrl);
        chapters.add(Chapter(
          name: name.trim(),
          url: absoluteUrl,
          isVolume: isVolume,
          isVip: isVip,
          updateTime: updateTime?.trim(),
          index: baseIndex + i + 1,
        ));
      }

      // 多页：求值 nextTocUrl
      final nextRule = rule.nextTocUrl;
      if (nextRule == null || nextRule.isEmpty) break;
      final nextRaw = ruleEngine.eval(body, nextRule);
      if (nextRaw == null || nextRaw.trim().isEmpty) break;
      final nextAbsolute = _resolveUrl(nextRaw.trim(), source.bookSourceUrl);
      if (nextAbsolute == currentUrl) break; // 防死循环
      currentUrl = nextAbsolute;
      pageIndex++;
    }

    return chapters;
  }

  String? _evalOnElement(element, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.evalOnElement(element, rule);
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
