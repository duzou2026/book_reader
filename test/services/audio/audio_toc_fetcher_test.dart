import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/audio/audio_toc_fetcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFetcher implements BookSourceFetcher {
  final Map<String, String> responses;
  _FakeFetcher(this.responses);

  @override
  Future<String> fetch(String url,
      {BookSource? source, Map<String, String>? headers}) async {
    if (!responses.containsKey(url)) {
      throw Exception('not found: $url');
    }
    return responses[url]!;
  }
}

void main() {
  late RuleEngine engine;
  late AudioTocFetcher fetcher;

  final source = BookSource(
    bookSourceName: '有声源',
    bookSourceUrl: 'https://audio.example.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
    ),
  );

  setUp(() {
    engine = RuleEngine();
  });

  group('AudioTocFetcher.fetch', () {
    test('extracts audio chapter list without audioUrl', () async {
      const html = '''
      <ul class="chapter-list">
        <li><a href="/c1" class="chapter-name">第一集</a></li>
        <li><a href="/c2" class="chapter-name">第二集</a></li>
      </ul>
      ''';
      fetcher = AudioTocFetcher(
        fetcher: _FakeFetcher({'https://audio.example.com/toc': html}),
        ruleEngine: engine,
      );
      final chapters =
          await fetcher.fetch('https://audio.example.com/toc', source);

      expect(chapters.length, 2);
      expect(chapters[0].name, '第一集');
      expect(chapters[0].url, 'https://audio.example.com/c1');
      expect(chapters[0].audioUrl, ''); // 暂未加载
      expect(chapters[0].index, 1);
    });

    test('returns empty when source has no ruleToc', () async {
      final noRuleSource = source.copyWith(ruleToc: null);
      fetcher = AudioTocFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final chapters = await fetcher.fetch(
          'https://audio.example.com/toc', noRuleSource);
      expect(chapters, isEmpty);
    });
  });
}
