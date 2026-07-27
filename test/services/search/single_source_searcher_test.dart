import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假 fetcher：按 URL 返回预置响应。
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
  late SingleSourceSearcher searcher;

  const html = '''
  <html><body>
    <ul class="book-list">
      <li>
        <a href="/book/1" class="title">三体</a>
        <span class="author">刘慈欣</span>
        <img src="/img/1.jpg" class="cover" />
        <p class="intro">科幻巨著</p>
      </li>
      <li>
        <a href="/book/2" class="title">活着</a>
        <span class="author">余华</span>
        <img src="/img/2.jpg" class="cover" />
        <p class="intro">当代文学</p>
      </li>
    </ul>
  </body></html>
  ''';

  final source = BookSource(
    bookSourceName: '测试源',
    bookSourceUrl: 'https://example.com',
    searchUrl: 'https://example.com/search?q={{key}}',
    ruleSearch: const RuleSearch(
      bookList: 'css:.book-list > li',
      name: 'css:.title@text',
      author: 'css:.author@text',
      coverUrl: 'css:.cover@src',
      intro: 'css:.intro@text',
      bookUrl: 'css:.title@href',
    ),
  );

  setUp(() {
    engine = RuleEngine();
  });

  group('SingleSourceSearcher.search', () {
    test('extracts all fields from each book node', () async {
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E4%B8%89%E4%BD%93': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);

      // 关键字「三体」匹配第一本，第二本「活着」不匹配会被过滤
      final results = await searcher.search('三体', source);

      expect(results.length, 1);

      expect(results[0].bookName, '三体');
      expect(results[0].author, '刘慈欣');
      expect(results[0].coverUrl, 'https://example.com/img/1.jpg');
      expect(results[0].intro, '科幻巨著');
      expect(results[0].sources.length, 1);
      expect(results[0].sources.first.sourceName, '测试源');
      expect(results[0].sources.first.bookUrl, 'https://example.com/book/1');
    });

    test('URL-encodes keyword in searchUrl', () async {
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E4%B8%89%E4%BD%93': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);

      final results = await searcher.search('三体', source);
      expect(results.length, 1);
      expect(results[0].bookName, '三体');
    });

    test('resolves absolute URLs in coverUrl', () async {
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E4%B8%89%E4%BD%93': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('三体', source);
      expect(results[0].coverUrl, startsWith('https://example.com/'));
    });

    test('returns empty list when fetch fails', () async {
      final fetcher = _FakeFetcher({}); // no responses
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('三体', source);
      expect(results, isEmpty);
    });

    test('returns empty list when source has no searchUrl', () async {
      final fetcher = _FakeFetcher({});
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final emptySource = source.copyWith(searchUrl: null);
      final results = await searcher.search('三体', emptySource);
      expect(results, isEmpty);
    });

    test('returns empty list when source has no ruleSearch', () async {
      final fetcher = _FakeFetcher({});
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final emptySource = source.copyWith(ruleSearch: null);
      final results = await searcher.search('三体', emptySource);
      expect(results, isEmpty);
    });

    test('skips entries missing name or bookUrl', () async {
      const brokenHtml = '''
      <ul class="book-list">
        <li><a href="/book/1" class="title">三体</a></li>
        <li><span class="title">无链接</span></li>
        <li><a href="" class="title">空链接</a></li>
      </ul>
      ''';
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E4%B8%89%E4%BD%93': brokenHtml,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('三体', source);
      expect(results.length, 1);
      expect(results[0].bookName, '三体');
    });
  });

  group('SingleSourceSearcher.search - 关键字相关性过滤', () {
    test('书名包含关键字 → 保留', () async {
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E4%B8%89%E4%BD%93': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('三体', source);
      expect(results.length, 1);
      expect(results[0].bookName, '三体');
    });

    test('作者包含关键字 → 保留（按作者搜的场景）', () async {
      // 关键字「刘慈欣」匹配第一本的作者
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E5%88%98%E6%85%88%E6%AC%A3': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('刘慈欣', source);
      expect(results.length, 1);
      expect(results[0].bookName, '三体');
      expect(results[0].author, '刘慈欣');
    });

    test('书名和作者都不含关键字 → 过滤掉', () async {
      // 关键字「哈利波特」既不在书名也不在作者，应全部过滤
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=%E5%93%88%E5%88%A9%E6%B3%A2%E7%89%B9': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('哈利波特', source);
      expect(results, isEmpty);
    });

    test('关键字大小写不敏感', () async {
      // 混合大小写关键字仍能匹配小写书名
      const lowerHtml = '''
      <ul class="book-list">
        <li><a href="/book/1" class="title">three body</a><span class="author"> Liu </span></li>
        <li><a href="/book/2" class="title">alive</a><span class="author">yu</span></li>
      </ul>
      ''';
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=THREE': lowerHtml,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('THREE', source);
      expect(results.length, 1);
      expect(results[0].bookName, 'three body');
    });

    test('关键字为空 → 全部保留（边界保护，避免误杀）', () async {
      final fetcher = _FakeFetcher({
        'https://example.com/search?q=': html,
      });
      searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);
      final results = await searcher.search('', source);
      // 空关键字不应过滤任何结果
      expect(results.length, 2);
    });
  });
}
