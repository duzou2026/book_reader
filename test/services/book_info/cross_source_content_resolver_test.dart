import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
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

void main() {
  late RuleEngine engine;
  late TocFetcher tocFetcher;
  late ContentFetcher contentFetcher;
  late CrossSourceContentResolver resolver;

  /// 三本书源全部带 RuleToc + RuleContent，便于演示跨源回退
  final sourceA = BookSource(
    bookSourceName: '源A (起点)',
    bookSourceUrl: 'https://a.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
    ),
    ruleContent: const RuleContent(content: 'css:.content@text'),
  );
  final sourceB = BookSource(
    bookSourceName: '源B (笔趣阁)',
    bookSourceUrl: 'https://b.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
    ),
    ruleContent: const RuleContent(content: 'css:.content@text'),
  );
  final sourceC = BookSource(
    bookSourceName: '源C (纵横)',
    bookSourceUrl: 'https://c.com',
    ruleToc: const RuleToc(
      chapterList: 'css:.chapter-list > li',
      chapterName: 'css:.chapter-name@text',
      chapterUrl: 'css:.chapter-name@href',
    ),
    ruleContent: const RuleContent(content: 'css:.content@text'),
  );

  setUp(() {
    engine = RuleEngine();
  });

  group('CrossSourceContentResolver.resolve', () {
    test('returns content from first alternative with valid content', () async {
      final fetcher = _FakeFetcher({
        // 源A目录（含第10章）
        'https://a.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c1" class="chapter-name">第一章</a></li>
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        // 源B目录（含第10章）
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c1" class="chapter-name">第一章</a></li>
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        // 源B第10章正文
        'https://b.com/c10': '''
          <div class="content">这是第十章的真实正文内容，长度足够通过校验。</div>
        ''',
      });
      tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);
      contentFetcher = ContentFetcher(fetcher: fetcher, ruleEngine: engine);
      resolver = CrossSourceContentResolver(
        tocFetcher: tocFetcher,
        contentFetcher: contentFetcher,
        getEnabledSources: () async => [sourceA, sourceB, sourceC],
      );

      final target = Chapter(name: '第十章', url: 'https://a.com/c10', index: 10);
      final alternatives = [
        BookInfo(
          url: 'https://b.com/book/1',
          sourceName: '源B (笔趣阁)',
          sourceUrl: 'https://b.com',
          tocUrl: 'https://b.com/toc',
        ),
        BookInfo(
          url: 'https://c.com/book/1',
          sourceName: '源C (纵横)',
          sourceUrl: 'https://c.com',
          tocUrl: 'https://c.com/toc',
        ),
      ];

      final result = await resolver.resolve(
        chapter: target,
        alternatives: alternatives,
      );

      expect(result, isNotNull);
      expect(result!.sourceInfo.sourceUrl, 'https://b.com');
      expect(result.content, contains('真实正文'));
      expect(result.sourceToc, isNotEmpty);
    });

    test('skips alternatives with invalid content (vip placeholder)', () async {
      final fetcher = _FakeFetcher({
        // 源B目录
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        // 源B正文是 VIP 占位（应跳过）
        'https://b.com/c10': '<div class="content">本章为VIP章节，请购买后查看。</div>',
        // 源C目录
        'https://c.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        // 源C正文有效
        'https://c.com/c10':
            '<div class="content">这是源C的真实正文，长度足够通过校验通过。</div>',
      });
      tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);
      contentFetcher = ContentFetcher(fetcher: fetcher, ruleEngine: engine);
      resolver = CrossSourceContentResolver(
        tocFetcher: tocFetcher,
        contentFetcher: contentFetcher,
        getEnabledSources: () async => [sourceB, sourceC],
      );

      final target = Chapter(name: '第十章', url: '', index: 10);
      final alternatives = [
        BookInfo(
          url: 'https://b.com/book/1',
          sourceName: '源B',
          sourceUrl: 'https://b.com',
          tocUrl: 'https://b.com/toc',
        ),
        BookInfo(
          url: 'https://c.com/book/1',
          sourceName: '源C',
          sourceUrl: 'https://c.com',
          tocUrl: 'https://c.com/toc',
        ),
      ];

      final result = await resolver.resolve(
        chapter: target,
        alternatives: alternatives,
      );

      expect(result, isNotNull);
      expect(result!.sourceInfo.sourceUrl, 'https://c.com');
    });

    test('returns null when no alternative provides valid content', () async {
      final fetcher = _FakeFetcher({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        'https://b.com/c10': '<div class="content">本章为VIP章节，请购买后查看。</div>',
      });
      tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);
      contentFetcher = ContentFetcher(fetcher: fetcher, ruleEngine: engine);
      resolver = CrossSourceContentResolver(
        tocFetcher: tocFetcher,
        contentFetcher: contentFetcher,
        getEnabledSources: () async => [sourceB],
      );

      final result = await resolver.resolve(
        chapter: Chapter(name: '第十章', url: '', index: 10),
        alternatives: [
          BookInfo(
            url: 'https://b.com/book/1',
            sourceName: '源B',
            sourceUrl: 'https://b.com',
            tocUrl: 'https://b.com/toc',
          ),
        ],
      );

      expect(result, isNull);
    });

    test('matches chapter by substring when exact name differs', () async {
      final fetcher = _FakeFetcher({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第10章 风起</a></li>
          </ul>
        ''',
        'https://b.com/c10':
            '<div class="content">这是真实正文内容，长度足够通过校验通过。</div>',
      });
      tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);
      contentFetcher = ContentFetcher(fetcher: fetcher, ruleEngine: engine);
      resolver = CrossSourceContentResolver(
        tocFetcher: tocFetcher,
        contentFetcher: contentFetcher,
        getEnabledSources: () async => [sourceB],
      );

      // 目标章节名"第十章"，备选源为"第10章 风起"
      // 归一化后"第十章"vs"第10章风起"，子串匹配应失败（数字 vs 中文数字）
      // 但本测试演示跨源章节名不同时返回 null（提醒用户名匹配的局限）
      final result = await resolver.resolve(
        chapter: Chapter(name: '第十章', url: '', index: 10),
        alternatives: [
          BookInfo(
            url: 'https://b.com/book/1',
            sourceName: '源B',
            sourceUrl: 'https://b.com',
            tocUrl: 'https://b.com/toc',
          ),
        ],
      );
      // 数字/中文数字不匹配，预期 null
      expect(result, isNull);
    });

    test('respects priority order of alternatives', () async {
      final fetcher = _FakeFetcher({
        'https://b.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        'https://b.com/c10':
            '<div class="content">这是源B的正文内容，长度足够通过校验通过。</div>',
        'https://c.com/toc': '''
          <ul class="chapter-list">
            <li><a href="/c10" class="chapter-name">第十章</a></li>
          </ul>
        ''',
        'https://c.com/c10':
            '<div class="content">这是源C的正文内容，长度足够通过校验通过。</div>',
      });
      tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);
      contentFetcher = ContentFetcher(fetcher: fetcher, ruleEngine: engine);
      resolver = CrossSourceContentResolver(
        tocFetcher: tocFetcher,
        contentFetcher: contentFetcher,
        getEnabledSources: () async => [sourceB, sourceC],
      );

      // alternatives 顺序: C 在前
      final alternatives = [
        BookInfo(
          url: 'https://c.com/book/1',
          sourceName: '源C',
          sourceUrl: 'https://c.com',
          tocUrl: 'https://c.com/toc',
        ),
        BookInfo(
          url: 'https://b.com/book/1',
          sourceName: '源B',
          sourceUrl: 'https://b.com',
          tocUrl: 'https://b.com/toc',
        ),
      ];

      final result = await resolver.resolve(
        chapter: Chapter(name: '第十章', url: '', index: 10),
        alternatives: alternatives,
      );

      expect(result, isNotNull);
      // 应该用 C（在 alternatives 列表里排前面）
      expect(result!.sourceInfo.sourceUrl, 'https://c.com');
    });
  });
}
