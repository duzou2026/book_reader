import 'package:book_reader/data/models/audio_chapter.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

/// 有声书目录 + 音频 URL 抓取器。
///
/// 设计：
///   - 复用 `RuleToc` 拿章节列表（与文本目录同规则）
///   - 对每个章节页应用 `RuleContent.content` 求值得到音频 URL
///
/// 性能注意：每章需独立请求详情页，对大目录会很慢。
/// 因此默认不在加载目录时抓取全部 audioUrl，而是按需懒加载
/// （详见 [GetAudioUrl] use case）。本类的 [fetchWithAudioUrls] 仅用于
/// 一次性预加载场景。
class AudioTocFetcher {
  final BookSourceFetcher fetcher;
  final RuleEngine ruleEngine;
  static const maxPages = 50;

  AudioTocFetcher({required this.fetcher, required this.ruleEngine});

  /// 抓取有声书目录（不含 audioUrl，audioUrl 留空）。
  Future<List<AudioChapter>> fetch(String tocUrl, BookSource source) async {
    final rule = source.ruleToc;
    if (rule == null) return const [];

    final chapters = <AudioChapter>[];
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
        chapters.add(AudioChapter(
          name: name.trim(),
          url: absoluteUrl,
          audioUrl: '',
          isVolume: isVolume,
          isVip: isVip,
          updateTime: updateTime?.trim(),
          index: baseIndex + i + 1,
        ));
      }

      final nextRule = rule.nextTocUrl;
      if (nextRule == null || nextRule.isEmpty) break;
      final nextRaw = ruleEngine.eval(body, nextRule);
      if (nextRaw == null || nextRaw.trim().isEmpty) break;
      final nextAbsolute = _resolveUrl(nextRaw.trim(), source.bookSourceUrl);
      if (nextAbsolute == currentUrl) break;
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
