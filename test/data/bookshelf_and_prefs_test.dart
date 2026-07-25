import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/services/preferences/reading_prefs_repository.dart';
import 'package:book_reader/services/preferences/reading_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookshelfEntry.makeId', () {
    test('normalizes whitespace and case', () {
      final a = BookshelfEntry.makeId('  三 体 ', 'LIU CiXin');
      final b = BookshelfEntry.makeId('三 体', 'liu cixin');
      expect(a, b);
      expect(a, '三 体|liu cixin');
    });

    test('distinguishes different books', () {
      expect(
        BookshelfEntry.makeId('三体', '刘慈欣'),
        isNot(BookshelfEntry.makeId('球状闪电', '刘慈欣')),
      );
      expect(
        BookshelfEntry.makeId('三体', '刘慈欣'),
        isNot(BookshelfEntry.makeId('三体', '王晋康')),
      );
    });
  });

  group('BookshelfEntry.copyWith', () {
    test('preserves id and addedAt, updates provided fields', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = BookshelfEntry(
        id: '三体|刘慈欣',
        bookName: '三体',
        author: '刘慈欣',
        sourceName: '笔趣阁',
        sourceUrl: 'https://biquge.com',
        bookUrl: 'https://biquge.com/1',
        lastReadAt: now,
        addedAt: now,
      );
      final updated = entry.copyWith(
        lastChapterIndex: 5,
        lastChapterName: '第五章',
        lastReadAt: now + 1000,
      );
      expect(updated.id, entry.id);
      expect(updated.addedAt, entry.addedAt);
      expect(updated.lastChapterIndex, 5);
      expect(updated.lastChapterName, '第五章');
      expect(updated.lastReadAt, now + 1000);
    });
  });

  group('ReadingPrefs', () {
    test('default values', () {
      const p = ReadingPrefs();
      expect(p.fontSize, 18);
      expect(p.lineHeight, 1.7);
      expect(p.backgroundIndex, 0);
      expect(p.pageMode, PageMode.scroll);
      expect(p.followSystemDark, isFalse);
    });

    test('round-trip JSON serialization', () {
      const original = ReadingPrefs(
        fontSize: 22,
        lineHeight: 1.9,
        backgroundIndex: 2,
        pageMode: PageMode.simulation,
        followSystemDark: true,
      );
      final json = original.toJson();
      final restored = ReadingPrefs.fromJson(json);
      expect(restored.fontSize, 22);
      expect(restored.lineHeight, 1.9);
      expect(restored.backgroundIndex, 2);
      expect(restored.pageMode, PageMode.simulation);
      expect(restored.followSystemDark, isTrue);
    });

    test('unknown pageMode falls back to scroll', () {
      final p = ReadingPrefs.fromJson({
        'fontSize': 18,
        'lineHeight': 1.7,
        'backgroundIndex': 0,
        'pageMode': 'unknown_mode',
        'followSystemDark': false,
      });
      expect(p.pageMode, PageMode.scroll);
    });

    test('missing fields fall back to defaults', () {
      final p = ReadingPrefs.fromJson({});
      expect(p.fontSize, 18);
      expect(p.lineHeight, 1.7);
      expect(p.backgroundIndex, 0);
      expect(p.pageMode, PageMode.scroll);
      expect(p.followSystemDark, isFalse);
    });

    test('copyWith only updates provided fields', () {
      const original = ReadingPrefs(fontSize: 20);
      final updated = original.copyWith(lineHeight: 2.0);
      expect(updated.fontSize, 20);
      expect(updated.lineHeight, 2.0);
      expect(updated.backgroundIndex, 0);
    });
  });

  group('ReadingProgress', () {
    test('copyWith only updates provided fields', () {
      const original = ReadingProgress(
        id: 'book1',
        chapterIndex: 3,
        scrollOffset: 100.0,
        lastReadAt: 1000,
      );
      final updated = original.copyWith(chapterIndex: 5);
      expect(updated.id, 'book1');
      expect(updated.chapterIndex, 5);
      expect(updated.scrollOffset, 100.0);
      expect(updated.lastReadAt, 1000);
      expect(updated.switchedSourceUrl, isNull);
    });

    test('round-trip JSON', () {
      const original = ReadingProgress(
        id: 'book1',
        chapterIndex: 5,
        scrollOffset: 250.5,
        lastReadAt: 9999,
        switchedSourceUrl: 'https://b.com',
      );
      final restored =
          ReadingProgress.fromJson(original.toJson());
      expect(restored.id, 'book1');
      expect(restored.chapterIndex, 5);
      expect(restored.scrollOffset, 250.5);
      expect(restored.lastReadAt, 9999);
      expect(restored.switchedSourceUrl, 'https://b.com');
    });
  });
}
