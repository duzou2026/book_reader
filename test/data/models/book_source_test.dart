import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/data/models/book_source.dart';

void main() {
  group('BookSource.fromJson', () {
    test('parses legado book source json with full fields', () {
      final json = {
        'bookSourceName': '测试源',
        'bookSourceUrl': 'https://www.example.com',
        'bookSourceType': 0,
        'enabled': true,
        'bookSourceGroup': '默认',
        'searchUrl': 'https://www.example.com/search?q={{key}}',
        'ruleSearch': {
          'bookList': 'css:.book-list > li',
          'name': 'css:.title@text',
          'author': 'css:.author@text',
          'bookUrl': 'css:a@href',
        },
        'ruleBookInfo': {
          'name': 'css:h1@text',
          'author': 'css:.author@text',
          'intro': 'css:.intro@text',
          'coverUrl': 'css:.cover@src',
        },
        'ruleToc': {
          'chapterList': 'css:.chapter-list li',
          'chapterName': 'css:a@text',
          'chapterUrl': 'css:a@href',
        },
        'ruleContent': {
          'content': 'css:.content@html',
        },
      };

      final source = BookSource.fromJson(json);

      expect(source.bookSourceName, '测试源');
      expect(source.bookSourceUrl, 'https://www.example.com');
      expect(source.bookSourceType, BookSourceType.text);
      expect(source.enabled, isTrue);
      expect(source.bookSourceGroup, '默认');
      expect(source.searchUrl, 'https://www.example.com/search?q={{key}}');
      expect(source.ruleSearch?.bookList, 'css:.book-list > li');
      expect(source.ruleSearch?.name, 'css:.title@text');
      expect(source.ruleSearch?.bookUrl, 'css:a@href');
      expect(source.ruleBookInfo?.name, 'css:h1@text');
      expect(source.ruleToc?.chapterList, 'css:.chapter-list li');
      expect(source.ruleContent?.content, 'css:.content@html');
    });

    test('parses audio book source type', () {
      final json = {
        'bookSourceName': '听书源',
        'bookSourceUrl': 'https://audio.example.com',
        'bookSourceType': 1,
      };
      final source = BookSource.fromJson(json);
      expect(source.bookSourceType, BookSourceType.audio);
    });

    test('uses defaults for missing optional fields', () {
      final json = {
        'bookSourceName': '最小源',
        'bookSourceUrl': 'https://min.example.com',
      };
      final source = BookSource.fromJson(json);
      expect(source.bookSourceType, BookSourceType.text);
      expect(source.enabled, isTrue);
      expect(source.priority, 0);
      expect(source.weight, 0);
      expect(source.ruleSearch, isNull);
      expect(source.searchUrl, isNull);
    });

    test('round-trips through fromJson/toJson', () {
      final json = {
        'bookSourceName': '回环源',
        'bookSourceUrl': 'https://rt.example.com',
        'bookSourceType': 0,
        'enabled': true,
        'searchUrl': 'https://rt.example.com/s?q={{key}}',
      };
      final source = BookSource.fromJson(json);
      final reEncoded = source.toJson();
      final source2 = BookSource.fromJson(reEncoded);
      expect(source2.bookSourceName, source.bookSourceName);
      expect(source2.bookSourceUrl, source.bookSourceUrl);
      expect(source2.searchUrl, source.searchUrl);
    });
  });
}
