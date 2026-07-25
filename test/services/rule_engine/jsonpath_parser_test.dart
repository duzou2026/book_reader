import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/jsonpath_parser.dart';

void main() {
  late JsonPathParser parser;

  const jsonStr = '{"data":{"books":[{"name":"三体"},{"name":"活着"}],"total":2}}';

  setUp(() {
    parser = JsonPathParser();
  });

  group('queryFirst', () {
    test('extracts single nested value', () {
      expect(parser.queryFirst(jsonStr, r'$.data.total'), '2');
    });

    test('extracts value from array by index', () {
      expect(parser.queryFirst(jsonStr, r'$.data.books[0].name'), '三体');
      expect(parser.queryFirst(jsonStr, r'$.data.books[1].name'), '活着');
    });

    test('strips @json: prefix', () {
      expect(parser.queryFirst(jsonStr, r'@json:$.data.total'), '2');
    });

    test('strips json: prefix', () {
      expect(parser.queryFirst(jsonStr, r'json:$.data.total'), '2');
    });

    test('returns null for non-existent path', () {
      expect(parser.queryFirst(jsonStr, r'$.data.notExist'), isNull);
    });

    test('handles top-level scalar', () {
      expect(parser.queryFirst('"hello"', r'$'), 'hello');
      expect(parser.queryFirst('42', r'$'), '42');
    });
  });

  group('queryList', () {
    test('extracts list via [*]', () {
      expect(parser.queryList(jsonStr, r'$.data.books[*].name'), ['三体', '活着']);
    });

    test('returns empty list for non-existent path', () {
      expect(parser.queryList(jsonStr, r'$.data.notExist[*]'), isEmpty);
    });
  });
}
