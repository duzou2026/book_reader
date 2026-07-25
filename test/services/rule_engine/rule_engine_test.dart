import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';

void main() {
  late RuleEngine engine;

  setUp(() {
    engine = RuleEngine();
  });

  const html = '<div class="title">三体</div><div class="author">刘慈欣</div>';
  const json = '{"data":{"name":"三体","author":"刘慈欣"}}';

  group('RuleEngine.eval', () {
    test('dispatches css rule with explicit prefix', () {
      expect(engine.eval(html, 'css:.title@text'), '三体');
      expect(engine.eval(html, '@css:.author@text'), '刘慈欣');
    });

    test('dispatches css rule without prefix (heuristic)', () {
      expect(engine.eval(html, '.title@text'), '三体');
    });

    test('dispatches json rule', () {
      expect(engine.eval(json, r'json:$.data.name'), '三体');
      expect(engine.eval(json, r'@json:$.data.author'), '刘慈欣');
    });

    test('returns plain string as-is', () {
      expect(engine.eval(html, 'just literal'), 'just literal');
    });

    test('returns null for unmatched css', () {
      expect(engine.eval(html, 'css:.not-exist@text'), isNull);
    });

    test('handles regex rule', () {
      const input = '<title>三体</title>';
      expect(engine.eval(input, r'regex:<title>(.+?)</title>'), '三体');
    });
  });

  group('RuleEngine.evalList', () {
    test('returns list from css bookList rule', () {
      const html = '''
      <ul class="book-list">
        <li>三体</li>
        <li>活着</li>
      </ul>
      ''';
      final list = engine.evalList(html, 'css:.book-list > li@text');
      expect(list, ['三体', '活着']);
    });

    test('returns list from json rule with [*]', () {
      const json = '{"data":[{"n":"a"},{"n":"b"}]}';
      final list = engine.evalList(json, r'json:$.data[*].n');
      expect(list, ['a', 'b']);
    });

    test('wraps single value in list for plain rule', () {
      final list = engine.evalList('x', 'just text');
      expect(list, ['just text']);
    });
  });
}
