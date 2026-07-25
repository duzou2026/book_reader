import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
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
  late BookInfoFetcher fetcher;

  const html = '''
  <html><body>
    <h1 class="book-name">三体</h1>
    <span class="author">刘慈欣</span>
    <img class="cover" src="/cover.jpg" />
    <p class="intro">科幻巨著，描述三体文明与地球文明的接触。</p>
    <span class="kind">科幻</span>
    <span class="word-count">100万字</span>
    <span class="last-chapter">最终章</span>
    <a class="toc-url" href="/toc">目录</a>
  </body></html>
  ''';

  final source = BookSource(
    bookSourceName: '测试源',
    bookSourceUrl: 'https://example.com',
    ruleBookInfo: const RuleBookInfo(
      name: 'css:.book-name@text',
      author: 'css:.author@text',
      intro: 'css:.intro@text',
      coverUrl: 'css:.cover@src',
      kind: 'css:.kind@text',
      wordCount: 'css:.word-count@text',
      lastChapter: 'css:.last-chapter@text',
      tocUrl: 'css:.toc-url@href',
    ),
  );

  setUp(() {
    engine = RuleEngine();
    fetcher = BookInfoFetcher(fetcher: _FakeFetcher({
      'https://example.com/book/1': html,
    }), ruleEngine: engine);
  });

  group('BookInfoFetcher.fetch', () {
    test('extracts all fields from book detail page', () async {
      final info = await fetcher.fetch('https://example.com/book/1', source);
      expect(info.name, '三体');
      expect(info.author, '刘慈欣');
      expect(info.intro, contains('科幻巨著'));
      expect(info.coverUrl, 'https://example.com/cover.jpg');
      expect(info.kind, '科幻');
      expect(info.wordCount, '100万字');
      expect(info.lastChapter, '最终章');
      expect(info.tocUrl, 'https://example.com/toc');
    });

    test('falls back to bookUrl as tocUrl when no tocUrl rule match', () async {
      final noTocSource = source.copyWith(
        ruleBookInfo: source.ruleBookInfo?.copyWith(tocUrl: null),
      );
      final info = await fetcher.fetch('https://example.com/book/1', noTocSource);
      expect(info.tocUrl, 'https://example.com/book/1');
    });

    test('returns minimal info when fetch fails', () async {
      fetcher = BookInfoFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final info = await fetcher.fetch('https://example.com/missing', source);
      expect(info.name, isNull);
      expect(info.url, 'https://example.com/missing');
      expect(info.sourceName, '测试源');
    });

    test('returns minimal info when source has no ruleBookInfo', () async {
      final emptySource = source.copyWith(ruleBookInfo: null);
      final info = await fetcher.fetch('https://example.com/book/1', emptySource);
      expect(info.name, isNull);
      expect(info.url, 'https://example.com/book/1');
    });
  });
}
