import 'package:book_reader/services/book_info/content_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentValidator.isValid', () {
    test('returns false for empty content', () {
      expect(ContentValidator.isValid(''), isFalse);
      expect(ContentValidator.isValid('   \n\t  '), isFalse);
    });

    test('returns false for content shorter than 20 chars', () {
      expect(ContentValidator.isValid('短内容'), isFalse);
      expect(ContentValidator.isValid('a'.padRight(19, 'a')), isFalse);
    });

    test('returns true for normal content', () {
      expect(
        ContentValidator.isValid('这是一段正常的章节正文内容，长度足够通过校验通过。'),
        isTrue,
      );
    });

    test('returns false for content with vip keywords', () {
      expect(
        ContentValidator.isValid('本章为VIP章节，请购买后查看完整内容。'),
        isFalse,
      );
      expect(
        ContentValidator.isValid('请登录后查看本章完整内容，谢谢支持。'),
        isFalse,
      );
      expect(
        ContentValidator.isValid('本章未购买，请充值后继续阅读。'),
        isFalse,
      );
      expect(
        ContentValidator.isValid('404 page not found'),
        isFalse,
      );
    });

    test('keyword matching is case-insensitive', () {
      expect(
        ContentValidator.isValid('This is a VIP章节 content with enough length.'),
        isFalse,
      );
    });
  });

  group('ContentValidator.isVip', () {
    test('returns true when isVip flag is true', () {
      expect(
        ContentValidator.isVip(true, '正常的长正文内容，长度足够通过校验。'),
        isTrue,
      );
    });

    test('returns false when flag is false and content is valid', () {
      expect(
        ContentValidator.isVip(false, '正常的长正文内容，长度足够通过校验通过。'),
        isFalse,
      );
    });

    test('returns true when flag is false but content is invalid', () {
      expect(
        ContentValidator.isVip(false, '请登录后查看'),
        isTrue,
      );
    });
  });
}
