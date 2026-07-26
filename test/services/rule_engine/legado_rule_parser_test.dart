import 'package:book_reader/services/rule_engine/legado_rule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegadoRuleParser.isLegadoRule', () {
    test('detects class./tag./id./children. prefix', () {
      expect(LegadoRuleParser.isLegadoRule('class.book-info.0'), isTrue);
      expect(LegadoRuleParser.isLegadoRule('tag.a.0'), isTrue);
      expect(LegadoRuleParser.isLegadoRule('id.content'), isTrue);
      expect(LegadoRuleParser.isLegadoRule('children'), isTrue);
    });

    test('detects multi-@ step chain as legado', () {
      // 就爱文学的真实规则：#author@tbody@tr!0
      expect(LegadoRuleParser.isLegadoRule('#author@tbody@tr!0'), isTrue);
      expect(LegadoRuleParser.isLegadoRule('div@span@text'), isTrue);
    });

    test('detects !N index syntax as legado', () {
      expect(LegadoRuleParser.isLegadoRule('tag.a!0'), isTrue);
      expect(LegadoRuleParser.isLegadoRule('tr!0'), isTrue);
    });

    test('single @ + known attr → NOT legado (CSS extractor)', () {
      expect(LegadoRuleParser.isLegadoRule('.title@text'), isFalse);
      expect(LegadoRuleParser.isLegadoRule('#foo@href'), isFalse);
    });

    test('strips known prefixes before checking', () {
      expect(LegadoRuleParser.isLegadoRule('@css:.foo'), isFalse);
      expect(LegadoRuleParser.isLegadoRule(r'json:$.data'), isFalse);
    });

    test('JSONPath not legado', () {
      expect(LegadoRuleParser.isLegadoRule(r'$.data.list'), isFalse);
      expect(LegadoRuleParser.isLegadoRule(r'$..book_data'), isFalse);
    });
  });

  group('LegadoRuleParser - 旧式类型前缀语法', () {
    const html = '''
    <div id="content">
      <div class="book-info">
        <a class="title">三体</a>
        <span class="author">刘慈欣</span>
      </div>
    </div>
    ''';

    test('class.xxx@text', () {
      final parser = LegadoRuleParser();
      expect(parser.queryFirst(html, 'class.title@text'), '三体');
      expect(parser.queryFirst(html, 'class.author@text'), '刘慈欣');
    });

    test('id.xxx@tag.xxx@text', () {
      final parser = LegadoRuleParser();
      expect(parser.queryFirst(html, 'id.content@class.title@text'), '三体');
    });

    test('class.xxx.N@index 形式', () {
      const listHtml = '''
      <ul class="list">
        <li>第一</li>
        <li>第二</li>
        <li>第三</li>
      </ul>
      ''';
      final parser = LegadoRuleParser();
      expect(parser.queryFirst(listHtml, 'class.list.0@text'), '第一');
      expect(parser.queryFirst(listHtml, 'class.list.1@text'), '第二');
    });
  });

  group('LegadoRuleParser - #id / .class 简写', () {
    const html = '''
    <div id="content">
      <table id="author"><tbody>
        <tr><td>第一行</td></tr>
        <tr><td>第二行</td></tr>
      </tbody></table>
      <div class="title">书名</div>
    </div>
    ''';

    test('#id 解析', () {
      final parser = LegadoRuleParser();
      // 单个 #id 不带后续 → 应能取到 #author 元素
      final elements = parser.queryElements(html, '#author');
      expect(elements, isNotEmpty);
      expect(elements.first.id, 'author');
    });

    test('#id@tag@tag!N 解析（就爱文学风格）', () {
      final parser = LegadoRuleParser();
      // #author → tbody → tr!0 → td@text
      final result = parser.queryFirst(html, '#author@tbody@tr!0@td@text');
      expect(result, '第一行');
    });

    test('#id@tag@tag!1 取第二行', () {
      final parser = LegadoRuleParser();
      final result = parser.queryFirst(html, '#author@tbody@tr!1@td@text');
      expect(result, '第二行');
    });

    test('.class 简写解析', () {
      final parser = LegadoRuleParser();
      final result = parser.queryFirst(html, '.title@text');
      expect(result, '书名');
    });
  });

  group('LegadoRuleParser - 复合属性提取', () {
    const html = '''
    <div class="book">
      <a href="/book/123" class="title">三体</a>
      <img src="/cover/123.jpg" class="cover" />
    </div>
    ''';

    test('@href 属性', () {
      final parser = LegadoRuleParser();
      expect(parser.queryFirst(html, 'class.title@href'), '/book/123');
    });

    test('@src 属性', () {
      final parser = LegadoRuleParser();
      expect(parser.queryFirst(html, 'class.cover@src'), '/cover/123.jpg');
    });
  });
}
