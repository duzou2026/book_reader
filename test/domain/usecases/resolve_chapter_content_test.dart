import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/domain/usecases/get_chapter_content.dart';
import 'package:book_reader/domain/usecases/resolve_chapter_content.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
import 'package:book_reader/services/book_info/cross_source_content_resolver.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFetcher implements BookSourceFetcher {
  final Map<String, String> responses;
  _FakeFetcher(this.responses);

  @override
  Future<String> fetch(String url,
      {BookSource? source, Map<String, String>? headers}) async {
    if (!responses.containsKey(url)) {
      throw Exception('not found: $url');
    }
    return responses[url]!;
  }
}

/// 可配置的 GetChapterContent 假实现。
class _FakeGetChapterContent implements GetChapterContent {
  /// key = "${book.sourceUrl}|${chapter.url}"，value = 正文。
  final Map<String, String> responses = {};

  /// 若抛错，key 对应的 entry 会被 throw。
  final Set<String> throwOn = {};

  @override
  ContentFetcher get fetcher => throw UnimplementedError();

  @override
  Future<String> call(BookInfo info, Chapter chapter) async {
    final key = '${info.sourceUrl}|${chapter.url}';
    if (throwOn.contains(key)) {
      throw Exception('mock error for $key');
    }
    return responses[key] ?? '';
  }
}

void main() {
  late RuleEngine engine;
  late TocFetcher tocFetcher;
  late ContentFetcher contentFetcher;
  late CrossSourceContentResolver resolver;
  late _FakeGetChapterContent fakeGetContent;
  late ResolveChapterContent useCase;

  final sourceA = BookSource(
    bookSourceName: '源A',
    bookSourceUrl: 'https://a.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
    ),
    ruleContent: const RuleContent(content: 'css:.content@text'),
  );
  final sourceB = BookSource(
    bookSourceName: '源B',
    bookSourceUrl: 'https://b.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
    ),
    ruleContent: const RuleContent(content: 'css:.content@text'),
  );

  final bookA = BookInfo(
    url: 'https://a.com/book/1',
    sourceName: '源A',
    sourceUrl: 'https://a.com',
  );
  final bookB = BookInfo(
    url: 'https://b.com/book/1',
    sourceName: '源B',
    sourceUrl: 'https://b.com',
    tocUrl: 'https://b.com/toc',
  );

  setUp(() {
    engine = RuleEngine();
    fakeGetContent = _FakeGetChapterContent();
  });

  /// 构造 resolver + useCase，使用给定 responses 模拟跨源抓取。
  void setupResolver(Map<String, String> responses) {
    final fetcher = _FakeFetcher(responses);
    tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);
    contentFetcher = ContentFetcher(fetcher: fetcher, ruleEngine: engine);
    resolver = CrossSourceContentResolver(
      tocFetcher: tocFetcher,
      contentFetcher: contentFetcher,
      getEnabledSources: () async => [sourceA, sourceB],
    );
    useCase = ResolveChapterContent(
      getContent: fakeGetContent,
      resolver: resolver,
    );
  }

  group('ResolveChapterContent', () {
    test('returns original content when valid and not VIP', () async {
      const chapter = Chapter(name: '第一章', url: 'https://a.com/c1', index: 1);
      const validContent = '这是一段足够长的正常正文内容，用于通过校验。';
      fakeGetContent.responses['https://a.com|https://a.com/c1'] = validContent;
      setupResolver({});

      final result = await useCase(
        book: bookA,
        chapter: chapter,
        alternatives: [bookB],
      );

      expect(result.content, validContent);
      expect(result.isVip, isFalse);
      expect(result.switchedTo, isNull);
    });

    test('falls back to cross-source when original is VIP placeholder',
        () async {
      const chapter =
          Chapter(name: '第十章', url: 'https://a.com/c10', index: 10);
      const vipContent = '本章为VIP章节，请购买后查看。';
      fakeGetContent.responses['https://a.com|https://a.com/c10'] = vipContent;
      setupResolver({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        'https://b.com/c10':
            '<div class="content">这是源B的真实正文内容，长度足够通过校验通过。</div>',
      });

      final result = await useCase(
        book: bookA,
        chapter: chapter,
        alternatives: [bookB],
      );

      expect(result.isVip, isTrue);
      expect(result.switchedTo, isNotNull);
      expect(result.switchedTo!.sourceUrl, 'https://b.com');
      expect(result.content, contains('真实正文'));
      expect(result.sourceToc, isNotEmpty);
    });

    test('returns original VIP content when no alternative provides valid content',
        () async {
      const chapter =
          Chapter(name: '第十章', url: 'https://a.com/c10', index: 10);
      const vipContent = '本章为VIP章节，请购买后查看。';
      fakeGetContent.responses['https://a.com|https://a.com/c10'] = vipContent;
      setupResolver({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        // 源B正文也是 VIP 占位
        'https://b.com/c10': '<div class="content">本章为VIP章节，请购买后查看。</div>',
      });

      final result = await useCase(
        book: bookA,
        chapter: chapter,
        alternatives: [bookB],
      );

      expect(result.isVip, isTrue);
      expect(result.switchedTo, isNull);
      // 返回原 VIP 占位正文，让 UI 兜底显示
      expect(result.content, vipContent);
    });

    test('falls back to cross-source when chapter.isVip flag is true',
        () async {
      const chapter = Chapter(
        name: '第十章',
        url: 'https://a.com/c10',
        index: 10,
        isVip: true,
      );
      // 即使原源返回了一些内容，因为 isVip=true 也应尝试跨源
      const originalContent = '这段正文虽然够长，但章节标记为VIP，应尝试跨源换源测试。';
      fakeGetContent.responses['https://a.com|https://a.com/c10'] = originalContent;
      setupResolver({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        'https://b.com/c10':
            '<div class="content">源B的免费正文内容，长度足够通过校验通过。</div>',
      });

      final result = await useCase(
        book: bookA,
        chapter: chapter,
        alternatives: [bookB],
      );

      expect(result.isVip, isTrue);
      expect(result.switchedTo, isNotNull);
      expect(result.switchedTo!.sourceUrl, 'https://b.com');
    });

    test('falls back to cross-source when original fetch throws', () async {
      const chapter =
          Chapter(name: '第十章', url: 'https://a.com/c10', index: 10);
      // 原源抓取抛错
      fakeGetContent.throwOn.add('https://a.com|https://a.com/c10');
      setupResolver({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        'https://b.com/c10':
            '<div class="content">源B的备用正文内容，长度足够通过校验通过。</div>',
      });

      final result = await useCase(
        book: bookA,
        chapter: chapter,
        alternatives: [bookB],
      );

      // 原源失败 → 视为无效 → 跨源解析
      expect(result.switchedTo, isNotNull);
      expect(result.content, contains('备用正文'));
      expect(result.isVip, isTrue);
    });
  });
}
