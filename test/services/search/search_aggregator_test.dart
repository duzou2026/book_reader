import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假 fetcher：按 URL 模式匹配返回不同 HTML。
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

  /// 构造一个测试源：name 由 sourceName 决定，搜索结果包含两本书
  BookSource makeSource(String name, String host) => BookSource(
        bookSourceName: name,
        bookSourceUrl: host,
        searchUrl: '$host/search?q={{key}}',
        ruleSearch: const RuleSearch(
          bookList: 'css:.book-list > li',
          name: 'css:.title@text',
          author: 'css:.author@text',
          bookUrl: 'css:.title@href',
          coverUrl: 'css:.cover@src',
          intro: 'css:.intro@text',
        ),
      );

  String htmlFor(String bookName, String author, String path) => '''
  <ul class="book-list">
    <li>
      <a href="$path" class="title">$bookName</a>
      <span class="author">$author</span>
      <img src="/img.jpg" class="cover" />
      <p class="intro">来自测试源的简介</p>
    </li>
  </ul>
  ''';

  setUp(() {
    engine = RuleEngine();
  });

  group('SearchAggregator.search', () {
    test('merges results from multiple sources for same book', () async {
      final sourceA = makeSource('源A', 'https://a.com');
      final sourceB = makeSource('源B', 'https://b.com');

      final fetcher = _FakeFetcher({
        'https://a.com/search?q=x': htmlFor('三体', '刘慈欣', '/book/1'),
        'https://b.com/search?q=x': htmlFor('三体', '刘慈欣', '/book/9'),
      });

      final searcher = SingleSourceSearcher(
        fetcher: fetcher,
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);

      final results = await aggregator.search('x', [sourceA, sourceB]);

      expect(results.length, 1);
      expect(results[0].bookName, '三体');
      expect(results[0].author, '刘慈欣');
      expect(results[0].sources.length, 2);
      expect(results[0].sources.map((s) => s.sourceName).toSet(), {'源A', '源B'});
    });

    test('dedupes by normalized name+author (whitespace differences)', () async {
      final sourceA = makeSource('源A', 'https://a.com');
      final sourceB = makeSource('源B', 'https://b.com');

      final fetcher = _FakeFetcher({
        'https://a.com/search?q=x': htmlFor('三体', '刘慈欣', '/1'),
        'https://b.com/search?q=x': htmlFor('  三体  ', ' 刘慈欣 ', '/2'),
      });

      final searcher = SingleSourceSearcher(
        fetcher: fetcher,
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);

      final results = await aggregator.search('x', [sourceA, sourceB]);
      expect(results.length, 1);
      expect(results[0].sources.length, 2);
    });

    test('keeps separate entries for different books', () async {
      final sourceA = makeSource('源A', 'https://a.com');
      final fetcher = _FakeFetcher({
        'https://a.com/search?q=x': '''
        <ul class="book-list">
          <li><a href="/1" class="title">三体</a><span class="author">刘慈欣</span></li>
          <li><a href="/2" class="title">活着</a><span class="author">余华</span></li>
        </ul>
        ''',
      });

      final searcher = SingleSourceSearcher(
        fetcher: fetcher,
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);

      final results = await aggregator.search('x', [sourceA]);
      expect(results.length, 2);
    });

    test('tolerates one source failing', () async {
      final sourceA = makeSource('源A', 'https://a.com');
      final sourceB = makeSource('源B', 'https://b.com');

      // 只配置 A 的响应，B 会抛异常
      final fetcher = _FakeFetcher({
        'https://a.com/search?q=x': htmlFor('三体', '刘慈欣', '/1'),
      });

      final searcher = SingleSourceSearcher(
        fetcher: fetcher,
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);

      final results = await aggregator.search('x', [sourceA, sourceB]);
      expect(results.length, 1);
      expect(results[0].bookName, '三体');
      expect(results[0].sources.length, 1);
      expect(results[0].sources.first.sourceName, '源A');
    });

    test('returns empty list when all sources fail', () async {
      final sourceA = makeSource('源A', 'https://a.com');
      final fetcher = _FakeFetcher({});

      final searcher = SingleSourceSearcher(
        fetcher: fetcher,
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);

      final results = await aggregator.search('x', [sourceA]);
      expect(results, isEmpty);
    });

    test('returns empty list for empty source list', () async {
      final searcher = SingleSourceSearcher(
        fetcher: _FakeFetcher({}),
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);
      final results = await aggregator.search('x', const []);
      expect(results, isEmpty);
    });

    test('sorts by sources count descending', () async {
      final sourceA = makeSource('源A', 'https://a.com');
      final sourceB = makeSource('源B', 'https://b.com');
      final sourceC = makeSource('源C', 'https://c.com');

      // 三体在 3 个源都有；活着只在 1 个源有
      final fetcher = _FakeFetcher({
        'https://a.com/search?q=x': htmlFor('三体', '刘', '/1'),
        'https://b.com/search?q=x': htmlFor('三体', '刘', '/2'),
        'https://c.com/search?q=x': '''
          <ul class="book-list">
            <li><a href="/3" class="title">三体</a><span class="author">刘</span></li>
            <li><a href="/4" class="title">活着</a><span class="author">余</span></li>
          </ul>
        ''',
      });

      final searcher = SingleSourceSearcher(
        fetcher: fetcher,
        ruleEngine: engine,
      );
      final aggregator = SearchAggregator(searcher: searcher);

      final results = await aggregator.search('x', [sourceA, sourceB, sourceC]);
      expect(results.length, 2);
      expect(results[0].bookName, '三体');
      expect(results[0].sources.length, 3);
      expect(results[1].bookName, '活着');
      expect(results[1].sources.length, 1);
    });
  });
}
