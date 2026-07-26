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

  group('RuleEngine.eval - || 备选规则', () {
    test('首个非空规则胜出', () {
      const html = '<div class="a">A</div><div class="b">B</div>';
      // 第一条命中 → A
      expect(engine.eval(html, 'css:.a@text||css:.b@text'), 'A');
    });

    test('首条空 → 用第二条', () {
      const html = '<div class="b">B</div>';
      // .a 不存在，回退到 .b
      expect(engine.eval(html, 'css:.a@text||css:.b@text'), 'B');
    });

    test('三条备选，最后一跳命中', () {
      const html = '<div class="c">C</div>';
      expect(
        engine.eval(html, 'css:.a@text||css:.b@text||css:.c@text'),
        'C',
      );
    });

    test('全部空 → 返回 null', () {
      const html = '<div></div>';
      expect(
        engine.eval(html, 'css:.a@text||css:.b@text'),
        isNull,
      );
    });

    test('JSONPath || 备选', () {
      // 笔阅读器真实场景：$.result.list||$.result..list[*]
      const json = '{"result":{"list":[{"n":"a"}]}}';
      expect(engine.eval(json, r'json:$.result.list[0].n'), 'a');
      // || 形式
      expect(
        engine.eval(json, r'json:$.result.list||json:$.result..list'),
        isNotNull,
      );
    });

    test('净化段 ##regex##replacement 与 || 共存', () {
      const html = '<div class="a">A1B2</div>';
      // 命中 .a → "A1B2"，再净化去掉数字 → "AB"
      expect(
        engine.eval(html, r'css:.a@text||css:.b@text##\d##'),
        'AB',
      );
    });

    test('regex 规则内的 || 不被分割（正则语义）', () {
      // regex 规则中的 || 是正则 OR，不是 legado 备选
      const input = 'cat or dog';
      expect(
        engine.eval(input, r'regex:(cat||dog)'),
        'cat',
      );
    });
  });

  group('RuleEngine.evalElements - <js>...</js> 回退', () {
    test('<js>...</js> 后接 JSONPath bookList → 用 fallback', () {
      // 模拟笔阅读器：JS 无法执行时回退到 JSONPath
      const json = '{"result":{"list":[{"n":"a"},{"n":"b"}]}}';
      // 注意：JSONPath 在 evalElements 里返回空（因为 Element 才能返回）
      // 但至少不应抛异常
      final elements = engine.evalElements(
        json,
        '<js>eval(String(source.bookSourceComment));decode(result);</js>\$.result.list||\$.result..list[*]',
      );
      // JSON 不会被 evalElements 当 Element 返回，所以是空（不抛异常即可）
      expect(elements, isEmpty);
    });

    test('<js>...</js> 后接 CSS bookList → 用 fallback CSS', () {
      const html = '''
      <ul class="book-list">
        <li>三体</li>
        <li>活着</li>
      </ul>
      ''';
      final elements = engine.evalElements(
        html,
        '<js>some side effect;</js>css:.book-list > li',
      );
      expect(elements.length, 2);
    });
  });
}
