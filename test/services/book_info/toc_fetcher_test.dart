import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
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
  late TocFetcher fetcher;

  final source = BookSource(
    bookSourceName: '测试源',
    bookSourceUrl: 'https://example.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
      isVip: 'css:.vip@text',
    ),
  );

  setUp(() {
    engine = RuleEngine();
  });

  group('TocFetcher.fetch', () {
    test('extracts chapter list from single page', () async {
      const html = '''
      <ul class="chapter-list">
        <li><a href="/c1" class="chapter-name">第一章</a></li>
        <li><a href="/c2" class="chapter-name">第二章</a></li>
        <li><a href="/c3" class="chapter-name">第三章</a></li>
      </ul>
      ''';
      fetcher = TocFetcher(
        fetcher: _FakeFetcher({'https://example.com/toc': html}),
        ruleEngine: engine,
      );

      final chapters = await fetcher.fetch('https://example.com/toc', source);

      expect(chapters.length, 3);
      expect(chapters[0].name, '第一章');
      expect(chapters[0].url, 'https://example.com/c1');
      expect(chapters[0].index, 1);
      expect(chapters[1].index, 2);
      expect(chapters[2].index, 3);
    });

    test('follows nextTocUrl for multi-page toc', () async {
      final multiSource = source.copyWith(
        ruleToc: source.ruleToc?.copyWith(
          nextTocUrl: 'css:.next@href',
        ),
      );
      final fetcher = TocFetcher(
        fetcher: _FakeFetcher({
          'https://example.com/toc': '''
            <ul class="chapter-list">
              <li><a href="/c1" class="chapter-name">第一章</a></li>
              <li><a href="/c2" class="chapter-name">第二章</a></li>
            </ul>
            <a class="next" href="/toc2">下一页</a>
          ''',
          'https://example.com/toc2': '''
            <ul class="chapter-list">
              <li><a href="/c3" class="chapter-name">第三章</a></li>
            </ul>
          ''',
        }),
        ruleEngine: engine,
      );

      final chapters = await fetcher.fetch('https://example.com/toc', multiSource);

      expect(chapters.length, 3);
      expect(chapters[2].name, '第三章');
      expect(chapters[2].index, 3);
    });

    test('marks vip chapters', () async {
      const html = '''
      <ul class="chapter-list">
        <li><a href="/c1" class="chapter-name">免费章</a></li>
        <li>
          <a href="/c2" class="chapter-name">VIP章</a>
          <span class="vip">true</span>
        </li>
      </ul>
      ''';
      fetcher = TocFetcher(
        fetcher: _FakeFetcher({'https://example.com/toc': html}),
        ruleEngine: engine,
      );

      final chapters = await fetcher.fetch('https://example.com/toc', source);
      expect(chapters[0].isVip, isFalse);
      expect(chapters[1].isVip, isTrue);
    });

    test('skips entries without name or url', () async {
      const html = '''
      <ul class="chapter-list">
        <li><a href="/c1" class="chapter-name">第一章</a></li>
        <li><a href="" class="chapter-name">空链接</a></li>
        <li><span class="chapter-name">无链接</span></li>
        <li><a href="/c4" class="chapter-name">第四章</a></li>
      </ul>
      ''';
      fetcher = TocFetcher(
        fetcher: _FakeFetcher({'https://example.com/toc': html}),
        ruleEngine: engine,
      );

      final chapters = await fetcher.fetch('https://example.com/toc', source);
      expect(chapters.length, 2);
      expect(chapters[0].name, '第一章');
      expect(chapters[1].name, '第四章');
    });

    test('returns empty when source has no ruleToc', () async {
      final noRuleSource = source.copyWith(ruleToc: null);
      fetcher = TocFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final chapters =
          await fetcher.fetch('https://example.com/toc', noRuleSource);
      expect(chapters, isEmpty);
    });

    test('stops when nextTocUrl points to same url (anti-loop)', () async {
      final loopSource = source.copyWith(
        ruleToc: source.ruleToc?.copyWith(
          nextTocUrl: 'css:.next@href',
        ),
      );
      const html = '''
      <ul class="chapter-list">
        <li><a href="/c1" class="chapter-name">第一章</a></li>
      </ul>
      <a class="next" href="/toc">循环</a>
      ''';
      fetcher = TocFetcher(
        fetcher: _FakeFetcher({'https://example.com/toc': html}),
        ruleEngine: engine,
      );

      final chapters = await fetcher.fetch('https://example.com/toc', loopSource);
      expect(chapters.length, 1);
    });
  });
}
