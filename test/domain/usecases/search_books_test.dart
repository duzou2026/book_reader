import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/domain/usecases/search_books.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFetcher implements BookSourceFetcher {
  final Map<String, String> responses;
  _FakeFetcher(this.responses);

  @override
  Future<String> fetch(String url,
      {BookSource? source, Map<String, String>? headers}) async {
    return responses[url] ?? (throw Exception('not found'));
  }
}

class _FakeRepository implements BookSourceRepository {
  final List<BookSource> sources;
  _FakeRepository(this.sources);

  @override
  Future<List<BookSource>> getEnabledSources() async => sources;

  @override
  Future<void> upsert(BookSource source) async {}

  @override
  Future<void> deleteByUrl(String bookSourceUrl) async {}

  @override
  Future<List<BookSource>> getAll() async => sources;

  @override
  Future<void> setEnabled(String bookSourceUrl, bool enabled) async {}

  @override
  Future<bool> contains(String bookSourceUrl) async => false;

  @override
  Future<void> clear() async {}
}

void main() {
  late RuleEngine engine;

  setUp(() {
    engine = RuleEngine();
  });

  group('SearchBooks use case', () {
    test('returns empty when repository has no sources', () async {
      final useCase = SearchBooks(
        aggregator: SearchAggregator(
          searcher: SingleSourceSearcher(
            fetcher: _FakeFetcher({}),
            ruleEngine: engine,
          ),
        ),
        repository: _FakeRepository(const []),
      );

      final results = await useCase('三体');
      expect(results, isEmpty);
    });

    test('aggregates results from repository sources', () async {
      final source = BookSource(
        bookSourceName: '源A',
        bookSourceUrl: 'https://a.com',
        searchUrl: 'https://a.com/search?q={{key}}',
        ruleSearch: const RuleSearch(
          bookList: 'css:.book-list > li',
          name: 'css:.title@text',
          author: 'css:.author@text',
          bookUrl: 'css:.title@href',
        ),
      );

      final fetcher = _FakeFetcher({
        'https://a.com/search?q=%E4%B8%89%E4%BD%93': '''
        <ul class="book-list">
          <li><a href="/1" class="title">三体</a><span class="author">刘慈欣</span></li>
        </ul>
        ''',
      });

      final useCase = SearchBooks(
        aggregator: SearchAggregator(
          searcher: SingleSourceSearcher(
            fetcher: fetcher,
            ruleEngine: engine,
          ),
        ),
        repository: _FakeRepository([source]),
      );

      final results = await useCase('三体');
      expect(results.length, 1);
      expect(results.first.bookName, '三体');
      expect(results.first.author, '刘慈欣');
    });
  });
}
