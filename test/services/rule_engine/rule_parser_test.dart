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
}
