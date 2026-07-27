import 'dart:convert';

import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 目录抓取器。
///
/// 对书源目录页应用 `RuleToc` 解析章节列表。
/// 支持多页目录：若 `nextTocUrl` 规则求值得到非空 URL，则继续抓取下一页，
/// 直到无 nextTocUrl 或达到 [maxPages] 上限。
///
/// chapterList 规则支持 CSS / legado 旧式 / XPath / JSON 四种。
/// JSON 规则（如 `$.data` 或 `$.result.pageList`）由 [_parseJsonChapters]
/// 兜底处理——RuleEngine.evalElements 对 JSON 返回空，需走 JSONPath 提取
/// 每个 JSON 对象，再对每个对象应用 chapterName/chapterUrl 等 JSONPath 规则。
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

      final baseIndex = chapters.length;

      // 先尝试 CSS / legado / XPath（返回 Element 列表）
      final elements = ruleEngine.evalElements(body, chapterListRule);
      if (elements.isNotEmpty) {
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
      } else {
        // JSON 兜底：chapterList 是 JSONPath（如 $.data / $.result.pageList）
        final jsonChapters = _parseJsonChapters(body, chapterListRule, rule);
        for (var i = 0; i < jsonChapters.length; i++) {
          final c = jsonChapters[i];
          final absoluteUrl = _resolveUrl(c.url, source.bookSourceUrl);
          chapters.add(Chapter(
            name: c.name.trim(),
            url: absoluteUrl,
            isVolume: c.isVolume,
            isVip: c.isVip,
            updateTime: c.updateTime?.trim(),
            index: baseIndex + i + 1,
          ));
        }
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

  /// 解析 JSON chapterList 规则。
  ///
  /// 用于酷我小说（`$.data`）、熊猫看书（`$.result.pageList`）等返回 JSON
  /// 的目录页。把整个响应解析为 JSON，用 JSONPath 取出章节对象列表，
  /// 再对每个对象应用 chapterName/chapterUrl 等 JSONPath 规则。
  ///
  /// 支持复合规则 `$.a&&$.b`（合并两个 JSONPath 结果）。
  List<_RawChapter> _parseJsonChapters(
    String body,
    String chapterListRule,
    RuleToc rule,
  ) {
    dynamic jsonData;
    try {
      jsonData = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (jsonData is! List && jsonData is! Map) return const [];

    final items = <dynamic>[];
    // 支持复合规则 && 合并
    for (final part in chapterListRule.split('&&')) {
      var path = part.trim();
      if (path.startsWith('json:') || path.startsWith('@json:')) {
        path = path.substring(path.indexOf(':') + 1);
      }
      final list = ruleEngine.evalList(jsonEncode(jsonData), path);
      for (final s in list) {
        dynamic decoded;
        try {
          decoded = jsonDecode(s);
        } catch (_) {
          decoded = s;
        }
        // $.data 这种不带 [*] 的路径会返回整个数组的 JSON 字符串，
        // 需要展开为各个元素；$.data[*] 则已经是逐个元素，无需展开。
        if (decoded is List) {
          items.addAll(decoded);
        } else {
          items.add(decoded);
        }
      }
    }
    if (items.isEmpty) return const [];

    final result = <_RawChapter>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final itemJson = jsonEncode(item);
      final name = _evalJsonField(itemJson, rule.chapterName);
      final url = _evalJsonField(itemJson, rule.chapterUrl);
      if (name == null || name.isEmpty || url == null || url.isEmpty) {
        continue;
      }
      final isVolume = _evalJsonField(itemJson, rule.isVolume) == 'true' ||
          _evalJsonField(itemJson, rule.isVolume) == '1';
      final isVip = _evalJsonField(itemJson, rule.isVip) == 'true' ||
          _evalJsonField(itemJson, rule.isVip) == '1';
      final updateTime = _evalJsonField(itemJson, rule.updateTime);
      result.add(_RawChapter(
        name: name,
        url: url,
        isVolume: isVolume,
        isVip: isVip,
        updateTime: updateTime,
      ));
    }
    return result;
  }

  String? _evalJsonField(String json, String? rule) {
    if (rule == null || rule.isEmpty) return null;
    return ruleEngine.eval(json, rule);
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

/// JSON 解析中间结构，仅用于 [_parseJsonChapters] 内部传递。
class _RawChapter {
  final String name;
  final String url;
  final bool isVolume;
  final bool isVip;
  final String? updateTime;
  _RawChapter({
    required this.name,
    required this.url,
    required this.isVolume,
    required this.isVip,
    this.updateTime,
  });
}
