import 'package:book_reader/data/hive_book_source_repository.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late HiveBookSourceRepository repo;
  late Box<String> box;

  setUp(() async {
    Hive.init('test_hive_data');
    box = await Hive.openBox<String>('book_sources_test');
    await box.clear();
    repo = HiveBookSourceRepository(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  group('HiveBookSourceRepository', () {
    test('upsert then getEnabledSources returns the source', () async {
      final src = BookSource(
        bookSourceName: '测试源',
        bookSourceUrl: 'https://example.com',
        searchUrl: 'https://example.com/search?q={{key}}',
      );
      await repo.upsert(src);
      final result = await repo.getEnabledSources();
      expect(result.length, 1);
      expect(result.first.bookSourceUrl, 'https://example.com');
    });

    test('getEnabledSources filters out disabled', () async {
      await repo.upsert(BookSource(
          bookSourceName: '启用', bookSourceUrl: 'https://a.com', enabled: true));
      await repo.upsert(BookSource(
          bookSourceName: '禁用', bookSourceUrl: 'https://b.com', enabled: false));
      final result = await repo.getEnabledSources();
      expect(result.length, 1);
      expect(result.first.bookSourceUrl, 'https://a.com');
    });

    test('getAll returns both enabled and disabled', () async {
      await repo.upsert(BookSource(
          bookSourceName: '启用', bookSourceUrl: 'https://a.com', enabled: true));
      await repo.upsert(BookSource(
          bookSourceName: '禁用', bookSourceUrl: 'https://b.com', enabled: false));
      final result = await repo.getAll();
      expect(result.length, 2);
    });

    test('upsert by same url overwrites', () async {
      await repo.upsert(BookSource(
          bookSourceName: '旧', bookSourceUrl: 'https://a.com'));
      await repo.upsert(BookSource(
          bookSourceName: '新', bookSourceUrl: 'https://a.com'));
      final result = await repo.getEnabledSources();
      expect(result.length, 1);
      expect(result.first.bookSourceName, '新');
    });

    test('deleteByUrl removes the source', () async {
      await repo.upsert(BookSource(
          bookSourceName: '测试', bookSourceUrl: 'https://a.com'));
      await repo.deleteByUrl('https://a.com');
      expect((await repo.getEnabledSources()), isEmpty);
    });

    test('preserves nested ruleSearch through round-trip', () async {
      final src = BookSource(
        bookSourceName: '带规则',
        bookSourceUrl: 'https://r.com',
        searchUrl: 'https://r.com/s?q={{key}}',
        ruleSearch: const RuleSearch(
          bookList: 'css:.book-list > li',
          name: 'css:.title@text',
          author: 'css:.author@text',
          bookUrl: 'css:.title@href',
        ),
      );
      await repo.upsert(src);
      final result = await repo.getEnabledSources();
      expect(result.first.ruleSearch?.bookList, 'css:.book-list > li');
      expect(result.first.ruleSearch?.name, 'css:.title@text');
    });
  });
}
