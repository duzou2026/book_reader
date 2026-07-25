import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/css_selector_parser.dart';

void main() {
  late CssSelectorParser parser;

  const html = '''
  <ul class="book-list">
    <li>
      <a href="/book/1" class="title">三体</a>
      <span class="author">刘慈欣</span>
      <img src="/img/1.jpg" class="cover" />
    </li>
    <li>
      <a href="/book/2" class="title">活着</a>
      <span class="author">余华</span>
      <img src="/img/2.jpg" class="cover" />
    </li>
  </ul>
  ''';

  setUp(() {
    parser = CssSelectorParser();
  });

  group('queryFirst', () {
    test('extracts text with explicit @text attr', () {
      final result = parser.queryFirst(html, '.book-list li:first-child .title@text');
      expect(result, '三体');
    });

    test('extracts attribute with @href', () {
      final result = parser.queryFirst(html, '.book-list li:first-child a.title@href');
      expect(result, '/book/1');
    });

    test('extracts src attribute', () {
      final result = parser.queryFirst(html, '.book-list li:first-child img.cover@src');
      expect(result, '/img/1.jpg');
    });

    test('extracts html', () {
      final result = parser.queryFirst(html, '.book-list li:first-child .author@html');
      expect(result, '刘慈欣');
    });

    test('returns null when selector does not match', () {
      final result = parser.queryFirst(html, '.does-not-exist@text');
      expect(result, isNull);
    });

    test('defaults to text when no @attr specified', () {
      final result = parser.queryFirst(html, '.book-list li:first-child .title');
      expect(result, '三体');
    });
  });

  group('queryList', () {
    test('extracts multiple elements text', () {
      final results = parser.queryList(html, '.book-list li .title@text');
      expect(results, ['三体', '活着']);
    });

    test('extracts multiple hrefs', () {
      final results = parser.queryList(html, '.book-list li a.title@href');
      expect(results, ['/book/1', '/book/2']);
    });

    test('returns empty list when no matches', () {
      final results = parser.queryList(html, '.no-match@text');
      expect(results, isEmpty);
    });
  });

  group('queryElements (returns Element list)', () {
    test('returns list of Elements for further processing', () {
      final elements = parser.queryElements(html, '.book-list > li');
      expect(elements.length, 2);
    });

    test('can extract per-element fields via extract()', () {
      final elements = parser.queryElements(html, '.book-list > li');
      final names = elements.map((e) => parser.extract(e, '.title@text')).toList();
      expect(names, ['三体', '活着']);
    });
  });
}
