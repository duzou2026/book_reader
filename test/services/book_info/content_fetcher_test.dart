import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
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
  late ContentFetcher fetcher;

  final source = BookSource(
    bookSourceName: '测试源',
    bookSourceUrl: 'https://example.com',
    ruleContent: const RuleContent(
      content: 'css:.content@html',
    ),
  );

  setUp(() {
    engine = RuleEngine();
  });

  group('ContentFetcher.fetch', () {
    test('extracts content from single page', () async {
      const html = '''
      <div class="content"><p>第一段。</p><p>第二段。</p></div>
      ''';
      fetcher = ContentFetcher(
        fetcher: _FakeFetcher({'https://example.com/c1': html}),
        ruleEngine: engine,
      );
      final content = await fetcher.fetch('https://example.com/c1', source);
      expect(content, contains('第一段'));
      expect(content, contains('第二段'));
    });

    test('follows nextContentUrl for multi-page content', () async {
      final multiSource = source.copyWith(
        ruleContent: source.ruleContent?.copyWith(
          nextContentUrl: 'css:.next@href',
        ),
      );
      fetcher = ContentFetcher(
        fetcher: _FakeFetcher({
          'https://example.com/c1': '''
            <div class="content"><p>第一页内容</p></div>
            <a class="next" href="/c1p2">下一页</a>
          ''',
          'https://example.com/c1p2': '''
            <div class="content"><p>第二页内容</p></div>
          ''',
        }),
        ruleEngine: engine,
      );
      final content = await fetcher.fetch('https://example.com/c1', multiSource);
      expect(content, contains('第一页内容'));
      expect(content, contains('第二页内容'));
      expect(content, contains('\n\n'));
    });

    test('applies replaceRegex to clean content', () async {
      final cleanSource = source.copyWith(
        ruleContent: source.ruleContent?.copyWith(
          replaceRegex: r'广告.\d+##\n||请收藏本站',
        ),
      );
      const html = '''
      <div class="content">正文内容广告.123请收藏本站结尾</div>
      ''';
      fetcher = ContentFetcher(
        fetcher: _FakeFetcher({'https://example.com/c1': html}),
        ruleEngine: engine,
      );
      final content = await fetcher.fetch('https://example.com/c1', cleanSource);
      expect(content, contains('正文内容'));
      expect(content, isNot(contains('广告.123')));
      expect(content, isNot(contains('请收藏本站')));
      expect(content, contains('结尾'));
    });

    test('returns empty when source has no ruleContent', () async {
      final noRuleSource = source.copyWith(ruleContent: null);
      fetcher = ContentFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final content = await fetcher.fetch('https://example.com/c1', noRuleSource);
      expect(content, '');
    });

    test('returns empty when fetch fails', () async {
      fetcher = ContentFetcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final content = await fetcher.fetch('https://example.com/missing', source);
      expect(content, '');
    });

    test('stops when nextContentUrl loops to same url', () async {
      final loopSource = source.copyWith(
        ruleContent: source.ruleContent?.copyWith(
          nextContentUrl: 'css:.next@href',
        ),
      );
      const html = '''
      <div class="content">正文</div>
      <a class="next" href="/c1">循环</a>
      ''';
      fetcher = ContentFetcher(
        fetcher: _FakeFetcher({'https://example.com/c1': html}),
        ruleEngine: engine,
      );
      final content = await fetcher.fetch('https://example.com/c1', loopSource);
      expect(content, '正文');
    });
  });
}
