import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/data/models/search_result.dart';

void main() {
  group('SearchResult.dedupKey', () {
    test('lowercases name and author', () {
      final r = SearchResult(bookName: '三体', author: '刘慈欣');
      expect(r.dedupKey, '三体|刘慈欣');
    });

    test('trims surrounding whitespace', () {
      final r = SearchResult(bookName: '  三体  ', author: '  刘慈欣  ');
      expect(r.dedupKey, '三体|刘慈欣');
    });

    test('collapses internal whitespace', () {
      final r = SearchResult(bookName: '三  体', author: '刘 慈 欣');
      expect(r.dedupKey, '三 体|刘 慈 欣');
    });

    test('same name+author produces same key', () {
      final r1 = SearchResult(bookName: '三体', author: '刘慈欣');
      final r2 = SearchResult(bookName: ' 三体 ', author: ' 刘慈欣 ');
      expect(r1.dedupKey, r2.dedupKey);
    });
  });

  group('SearchResult.mergeSources', () {
    test('merges sources from another result with same dedupKey', () {
      final r1 = SearchResult(
        bookName: '三体',
        author: '刘慈欣',
        coverUrl: 'http://a.com/cover.jpg',
        sources: [
          SearchSource(sourceName: 'A', sourceUrl: 'https://a.com', bookUrl: 'https://a.com/1'),
        ],
      );
      final r2 = SearchResult(
        bookName: '三体',
        author: '刘慈欣',
        intro: '科幻巨著',
        sources: [
          SearchSource(sourceName: 'B', sourceUrl: 'https://b.com', bookUrl: 'https://b.com/1'),
        ],
      );
      final merged = r1.mergeWith(r2);
      expect(merged.bookName, '三体');
      expect(merged.sources.length, 2);
      expect(merged.sources.map((s) => s.sourceName).toList(), ['A', 'B']);
      expect(merged.coverUrl, 'http://a.com/cover.jpg');
      expect(merged.intro, '科幻巨著');
    });

    test('does not overwrite existing optional fields with null', () {
      final r1 = SearchResult(
        bookName: '三体',
        author: '刘',
        intro: '原 intro',
        sources: [SearchSource(sourceName: 'A', sourceUrl: 'https://a.com', bookUrl: 'https://a.com/1')],
      );
      final r2 = SearchResult(
        bookName: '三体',
        author: '刘',
        sources: [SearchSource(sourceName: 'B', sourceUrl: 'https://b.com', bookUrl: 'https://b.com/1')],
      );
      final merged = r1.mergeWith(r2);
      expect(merged.intro, '原 intro');
    });
  });

  group('SearchResult.fromJson', () {
    test('round-trips through fromJson/toJson', () {
      final r = SearchResult(
        bookName: '三体',
        author: '刘慈欣',
        coverUrl: 'http://x.com/1.jpg',
        sources: [
          SearchSource(sourceName: 'A', sourceUrl: 'https://a.com', bookUrl: 'https://a.com/1'),
        ],
      );
      final json = r.toJson();
      final r2 = SearchResult.fromJson(json);
      expect(r2.bookName, r.bookName);
      expect(r2.author, r.author);
      expect(r2.coverUrl, r.coverUrl);
      expect(r2.sources.length, 1);
      expect(r2.sources.first.sourceName, 'A');
    });
  });
}
