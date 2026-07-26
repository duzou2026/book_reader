import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/rule_parser.dart';

void main() {
  late RuleParser parser;

  setUp(() {
    parser = RuleParser();
  });

  group('RuleParser.detect', () {
    test('detects css selector rule', () {
      expect(parser.detect('css:.title@text'), RuleType.css);
      expect(parser.detect('@css:.title'), RuleType.css);
      expect(parser.detect('.title@text'), RuleType.css);
    });

    test('detects json rule', () {
      expect(parser.detect(r'json:$.data.title'), RuleType.json);
      expect(parser.detect(r'@json:$.data.title'), RuleType.json);
      expect(parser.detect(r'$..title'), RuleType.json);
    });

    test('detects xpath rule', () {
      expect(parser.detect('xpath://div[@class="title"]'), RuleType.xpath);
      expect(parser.detect('@xpath://div'), RuleType.xpath);
    });

    test('detects regex rule', () {
      expect(parser.detect(r'regex:title":"([^"]+)'), RuleType.regex);
      expect(parser.detect(r'@regex:title":"([^"]+)'), RuleType.regex);
    });

    test('detects js rule', () {
      expect(parser.detect('js:result.title'), RuleType.js);
      expect(parser.detect('@js:result.title'), RuleType.js);
      expect(parser.detect('<js>result.title</js>'), RuleType.js);
    });

    test('detects plain string as default', () {
      expect(parser.detect('just literal text'), RuleType.plain);
      expect(parser.detect(''), RuleType.plain);
    });
  });

  group('RuleParser.detect - legado vs CSS 区分', () {
    test('多 @ 步骤链 → legado（非 CSS）', () {
      // 就爱文学真实规则
      expect(parser.detect('#author@tbody@tr!0'), RuleType.legado);
      expect(parser.detect('div@span@text'), RuleType.legado);
      expect(parser.detect('class.foo@tag.a@text'), RuleType.legado);
    });

    test('!N 索引语法 → legado', () {
      expect(parser.detect('tag.a!0'), RuleType.legado);
      expect(parser.detect('tr!0'), RuleType.legado);
    });

    test('单 @ + 属性名 → CSS（属性提取器）', () {
      expect(parser.detect('.title@text'), RuleType.css);
      expect(parser.detect('#foo@href'), RuleType.css);
    });

    test('纯 CSS 选择器仍判为 CSS', () {
      expect(parser.detect('.search-card'), RuleType.css);
      expect(parser.detect('.v-list-item'), RuleType.css);
      expect(parser.detect('#content'), RuleType.css);
      expect(parser.detect('.foo > .bar'), RuleType.css);
    });
  });
}
