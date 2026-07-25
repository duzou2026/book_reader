import 'package:book_reader/services/book_info/content_purifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentPurifier', () {
    test('returns original when rules empty', () {
      expect(ContentPurifier.purify('hello', ''), 'hello');
      expect(ContentPurifier.purify('hello', '   '), 'hello');
    });

    test('replaces plain regex with empty', () {
      expect(ContentPurifier.purify('a1b2c3', r'\d'), 'abc');
    });

    test('replaces with explicit replacement', () {
      expect(
        ContentPurifier.purify('a1b2', r'\d##X'),
        'aXbX',
      );
    });

    test('multiple rules separated by actual newline', () {
      const content = '广告：xxx\n正文第一段\n广告：yyy';
      const rules = r'(?m)^广告：.*$\n?';
      final result = ContentPurifier.purify(content, rules);
      expect(result.contains('广告'), isFalse);
      expect(result.contains('正文第一段'), isTrue);
    });

    test('multiple rules separated by ||', () {
      const content = 'AAA BBB CCC';
      const rules = 'AAA##X||BBB##Y';
      expect(ContentPurifier.purify(content, rules), 'X Y CCC');
    });

    test('multiple rules separated by literal \\n', () {
      const content = 'AAA BBB';
      // 字符串里是反斜杠+n 两字符
      const rules = r'AAA##X\nBBB##Y';
      expect(ContentPurifier.purify(content, rules), 'X Y');
    });

    test('captures groups with \$1 reference', () {
      const content = 'http://example.com 点击';
      const rules = r'(http://\S+)##<a href="$1">链接</a>';
      final result = ContentPurifier.purify(content, rules);
      expect(result, '<a href="http://example.com">链接</a> 点击');
    });

    test('captures multiple groups with \$1 and \$2', () {
      const content = 'name=alice age=30';
      const rules = r'(\w+)=(\w+)##$2:$1';
      final result = ContentPurifier.purify(content, rules);
      expect(result, 'alice:name 30:age');
    });

    test('captures named group with \$<name>', () {
      const content = '2024-01-15';
      const rules =
          r'(?<year>\d+)-(?<month>\d+)-(?<day>\d+)##$<day>/$<month>/$<year>';
      final result = ContentPurifier.purify(content, rules);
      expect(result, '15/01/2024');
    });

    test('captures with \${1} braced form', () {
      const content = 'v1.2.3';
      const rules = r'v(\d+)\.(\d+)\.(\d+)##version ${1}.${2}.${3}';
      final result = ContentPurifier.purify(content, rules);
      expect(result, 'version 1.2.3');
    });

    test('(?i) prefix for case-insensitive', () {
      const content = 'Hello WORLD hello';
      const rules = r'(?i)hello';
      expect(ContentPurifier.purify(content, rules), ' WORLD ');
    });

    test('(?im) combined flags', () {
      const content = 'Hello\nhello\nHELLO';
      const rules = r'(?im)^hello$';
      final result = ContentPurifier.purify(content, rules);
      expect(result.trim().isEmpty, isTrue);
    });

    test('(?s) dotAll flag', () {
      const content = 'a.b';
      // . 默认不匹配换行；(?s) 让 . 匹配所有字符
      const rules = r'(?s)a.b';
      expect(ContentPurifier.purify('a\nb', rules), '');
      expect(ContentPurifier.purify(content, rules), '');
    });

    test('invalid regex is skipped silently', () {
      const content = 'hello';
      // 未闭合的 [
      const rules = r'[invalid';
      expect(ContentPurifier.purify(content, rules), 'hello');
    });

    test('invalid rule mixed with valid rules', () {
      const content = 'AAA BBB CCC';
      const rules = 'AAA##X||[invalid||BBB##Y';
      final result = ContentPurifier.purify(content, rules);
      expect(result, 'X Y CCC');
    });

    test('replacement containing ## literal', () {
      const content = 'key=value';
      const rules = r'(\w+)=(\w+)##$1##$2';
      final result = ContentPurifier.purify(content, rules);
      expect(result, 'key##value');
    });

    test('rule with empty pattern after ## is skipped', () {
      const content = 'hello';
      const rules = '##replacement';
      expect(ContentPurifier.purify(content, rules), 'hello');
    });

    test('whitespace-only rules ignored', () {
      const content = 'hello';
      const rules = '   \n  \n';
      expect(ContentPurifier.purify(content, rules), 'hello');
    });

    test('handles unicode (chinese) characters', () {
      const content = '本章正文。\n请访问 m.example.com 看完整内容';
      const rules = r'请访问.*$';
      final result = ContentPurifier.purify(content, rules);
      expect(result.contains('请访问'), isFalse);
      expect(result.contains('本章正文'), isTrue);
    });
  });

  group('ContentPurifier.validate', () {
    test('empty returns 0 rules', () {
      final r = ContentPurifier.validate('');
      expect(r.ruleCount, 0);
      expect(r.errorCount, 0);
      expect(r.isValid, isTrue);
    });

    test('all valid rules', () {
      const rules = r'\d##X\n\w';
      final r = ContentPurifier.validate(rules);
      expect(r.ruleCount, 2);
      expect(r.errorCount, 0);
      expect(r.isValid, isTrue);
    });

    test('mixed valid and invalid rules', () {
      const rules = r'\d##X||[invalid||\w';
      final r = ContentPurifier.validate(rules);
      expect(r.ruleCount, 3);
      expect(r.errorCount, 1);
      expect(r.isValid, isFalse);
      expect(r.errors.length, 1);
      expect(r.errors.first, contains('正则无效'));
    });

    test('reports format error for empty pattern', () {
      const rules = '##replacement';
      final r = ContentPurifier.validate(rules);
      expect(r.ruleCount, 1);
      expect(r.errorCount, 1);
      expect(r.errors.first, contains('格式错误'));
    });

    test('validates (?i) prefix as valid', () {
      const rules = r'(?i)hello';
      final r = ContentPurifier.validate(rules);
      expect(r.ruleCount, 1);
      expect(r.errorCount, 0);
      expect(r.isValid, isTrue);
    });
  });
}
