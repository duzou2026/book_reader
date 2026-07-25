import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_source/book_source_importer.dart';
import 'package:book_reader/services/book_source/book_source_validator.dart';

void main() {
  late BookSourceImporter importer;

  setUp(() {
    importer = BookSourceImporter();
  });

  group('BookSourceImporter.parse', () {
    test('imports single source object', () {
      final list = importer.parse('''
        {"bookSourceName":"源A","bookSourceUrl":"https://a.com"}
      ''');
      expect(list.length, 1);
      expect(list.first.bookSourceName, '源A');
      expect(list.first.bookSourceUrl, 'https://a.com');
    });

    test('imports source array', () {
      final list = importer.parse('''
        [
          {"bookSourceName":"A","bookSourceUrl":"https://a.com"},
          {"bookSourceName":"B","bookSourceUrl":"https://b.com"}
        ]
      ''');
      expect(list.length, 2);
      expect(list.map((s) => s.bookSourceName).toList(), ['A', 'B']);
    });

    test('dedupes by bookSourceUrl keeping first', () {
      final list = importer.parse('''
        [
          {"bookSourceName":"A","bookSourceUrl":"https://a.com"},
          {"bookSourceName":"A2","bookSourceUrl":"https://a.com"}
        ]
      ''');
      expect(list.length, 1);
      expect(list.first.bookSourceName, 'A');
    });

    test('parses nested rules', () {
      final list = importer.parse('''
        {
          "bookSourceName":"源X",
          "bookSourceUrl":"https://x.com",
          "ruleSearch":{"bookList":"css:.list > li","name":"css:.title@text"}
        }
      ''');
      expect(list.first.ruleSearch?.bookList, 'css:.list > li');
      expect(list.first.ruleSearch?.name, 'css:.title@text');
    });

    test('rejects missing bookSourceName', () {
      expect(
        () => importer.parse('{"bookSourceUrl":"https://a.com"}'),
        throwsA(isA<BookSourceValidationException>()),
      );
    });

    test('rejects missing bookSourceUrl', () {
      expect(
        () => importer.parse('{"bookSourceName":"A"}'),
        throwsA(isA<BookSourceValidationException>()),
      );
    });

    test('rejects empty name', () {
      expect(
        () => importer.parse('{"bookSourceName":"","bookSourceUrl":"https://a.com"}'),
        throwsA(isA<BookSourceValidationException>()),
      );
    });

    test('rejects non-object JSON (e.g. number)', () {
      expect(
        () => importer.parse('42'),
        throwsA(isA<BookSourceValidationException>()),
      );
    });

    test('handles whitespace and BOM in input', () {
      final list = importer.parse(
        '  \n {"bookSourceName":"A","bookSourceUrl":"https://a.com"} \n  ',
      );
      expect(list.length, 1);
    });

    test('returns empty list for empty array', () {
      expect(importer.parse('[]'), isEmpty);
    });

    test('skips invalid entries when throwOnInvalid is false', () {
      final list = importer.parse(
        '''
        [
          {"bookSourceName":"A","bookSourceUrl":"https://a.com"},
          {"bookSourceName":""},
          {"bookSourceName":"B","bookSourceUrl":"https://b.com"}
        ]
        ''',
        throwOnInvalid: false,
      );
      expect(list.length, 2);
      expect(list.map((s) => s.bookSourceName).toList(), ['A', 'B']);
    });
  });
}
