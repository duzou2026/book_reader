import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/audio/audio_url_fetcher.dart';
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
  late AudioUrlFetcher fetcher;

  final source = BookSource(
    bookSourceName: '有声源',
    bookSourceUrl: 'https://audio.example.com',
    ruleContent: const RuleContent(
      content: 'css:.audio-url@href',
    ),
  );

  setUp(() {
    engine = RuleEngine();
  });

  group('AudioUrlFetcher.fetch', () {
    test('extracts audio url from chapter page', () async {
      const html = '''
      <a class="audio-url" href="https://cdn.example.com/ep1.mp3">播放</a>
      ''';
      fetcher = AudioUrlFetcher(
        fetcher: _FakeFetcher({'https://audio.example.com/c1': html}),
        ruleEngine: engine,
      );
      final url = await fetcher.fetch('https://audio.example.com/c1', source);
      expect(url, 'https://cdn.example.com/ep1.mp3');
    });

    test('resolves relative audio url', () async {
      const html = '''
      <a class="audio-url" href="/files/ep2.mp3">播放</a>
      ''';
      fetcher = AudioUrlFetcher(
        fetcher: _FakeFetcher({'https://audio.example.com/c2': html}),
        ruleEngine: engine,
      );
      final url = await fetcher.fetch('https://audio.example.com/c2', source);
      expect(url, 'https://audio.example.com/files/ep2.mp3');
    });

    test('returns empty when no ruleContent', () async {
      final noRuleSource = source.copyWith(ruleContent: null);
      fetcher = AudioUrlFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final url = await fetcher.fetch('https://x.com/c1', noRuleSource);
      expect(url, '');
    });

    test('returns empty when fetch fails', () async {
      fetcher = AudioUrlFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final url = await fetcher.fetch('https://x.com/missing', source);
      expect(url, '');
    });
  });
}
