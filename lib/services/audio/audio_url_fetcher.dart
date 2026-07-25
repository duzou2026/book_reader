import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 单章音频 URL 抓取器。
///
/// 对章节页应用 `RuleContent.content` 求值得到音频文件 URL。
/// 这是听书场景下的「按需懒加载」：用户切到某章时才请求该章详情页拿音频 URL。
class AudioUrlFetcher {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;

  AudioUrlFetcher({required this.fetcher, required this.ruleEngine});

  /// 抓取并返回音频 URL。失败或无规则时返回空字符串。
  Future<String> fetch(String chapterUrl, BookSource source) async {
    final rule = source.ruleContent;
    if (rule == null) return '';

    final String body;
    try {
      body = await fetcher.fetch(chapterUrl, source: source);
    } catch (_) {
      return '';
    }

    final contentRule = rule.content;
    if (contentRule == null || contentRule.isEmpty) return '';
    final audioUrl = ruleEngine.eval(body, contentRule);
    if (audioUrl == null || audioUrl.trim().isEmpty) return '';

    return _resolveUrl(audioUrl.trim(), source.bookSourceUrl);
  }

  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'http:$url';
    try {
      final base = Uri.parse(baseUrl);
      if (url.startsWith('/')) return '${base.scheme}://${base.host}$url';
      final baseDir =
          base.path.substring(0, base.path.lastIndexOf('/') + 1);
      return '${base.scheme}://${base.host}$baseDir$url';
    } catch (_) {
      return url;
    }
  }
}
