import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/regex_parser.dart';

void main() {
  late RegexParser parser;

  setUp(() {
    parser = RegexParser();
  });

  group('queryFirst', () {
    test('returns first capture group when present', () {
      const input = '<title>三体 - 刘慈欣</title>';
      expect(parser.queryFirst(input, r'regex:<title>(.+?)</title>'), '三体 - 刘慈欣');
    });

    test('returns full match when no capture group', () {
      const input = '版本号 v1.2.3';
      expect(parser.queryFirst(input, r'regex:v\d+\.\d+\.\d+'), 'v1.2.3');
    });

    test('strips @regex: prefix', () {
      const input = '<title>三体</title>';
      expect(parser.queryFirst(input, r'@regex:<title>(.+?)</title>'), '三体');
    });

    test('returns null when no match', () {
      const input = 'no title here';
      expect(parser.queryFirst(input, r'regex:<title>(.+?)</title>'), isNull);
    });
  });

  group('queryList', () {
    test('returns all matches', () {
      const input = '章节：第一章。 章节：第二章。 章节：第三章。';
      expect(
        parser.queryList(input, r'regex:章节：(.+?)。'),
        ['第一章', '第二章', '第三章'],
      );
    });

    test('returns full matches when no capture group', () {
      const input = 'a1 b2 c3';
      expect(parser.queryList(input, r'regex:[a-z]\d'), ['a1', 'b2', 'c3']);
    });

    test('returns empty list when no match', () {
      expect(parser.queryList('nothing', r'regex:\d+'), isEmpty);
    });
  });
}
