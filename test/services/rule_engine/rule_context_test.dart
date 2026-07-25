import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/rule_context.dart';

void main() {
  group('RuleContext.substitute', () {
    test('substitutes {{key}} with raw keyword in non-url template', () {
      final ctx = RuleContext(keyword: '三体', page: 1);
      expect(ctx.substitute('search={{key}}'), 'search=三体');
    });

    test('encodes {{key}} when in http url', () {
      final ctx = RuleContext(keyword: '三体 刘慈欣', page: 1);
      final result = ctx.substitute('https://x.com/s?q={{key}}');
      expect(result, contains('%20'));
      expect(result, isNot(contains('三体 刘慈欣')));
    });

    test('substitutes {{page}} with page number', () {
      final ctx = RuleContext(keyword: '', page: 3);
      expect(ctx.substitute('https://x.com/s?p={{page}}'), 'https://x.com/s?p=3');
    });

    test('does not encode when not in url', () {
      final ctx = RuleContext(keyword: '三体', page: 1);
      expect(ctx.substitute('search={{key}}'), 'search=三体');
    });

    test('stores and retrieves rule variables via put/get', () {
      final ctx = RuleContext(keyword: '', page: 1);
      ctx.put('token', 'abc123');
      expect(ctx.get('token'), 'abc123');
      expect(ctx.substitute('auth={{token}}'), 'auth=abc123');
    });

    test('substitutes multiple variables in one template', () {
      final ctx = RuleContext(keyword: '三体', page: 2);
      ctx.put('uid', '42');
      final result = ctx.substitute('https://x.com/{{uid}}/s?q={{key}}&p={{page}}');
      // URL 中 keyword 会被编码
      expect(result, 'https://x.com/42/s?q=%E4%B8%89%E4%BD%93&p=2');
    });

    test('encodes page variable in url', () {
      final ctx = RuleContext(keyword: '', page: 5);
      final result = ctx.substitute('https://x.com/s?p={{page}}');
      expect(result, 'https://x.com/s?p=5');
    });

    test('handles keyword with special chars', () {
      final ctx = RuleContext(keyword: 'a&b=c', page: 1);
      final result = ctx.substitute('https://x.com/s?q={{key}}');
      expect(result, contains('a%26b%3Dc'));
    });
  });
}
