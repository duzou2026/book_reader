import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// 真实书源端到端验证：酷我小说（JSON API 源）。
///
/// 这些响应来自酷我小说真实 API（http://appi.kuwo.cn）的录制快照，
/// 用于验证 {{$.path}} 模板替换、init 解包、JSONPath 字段提取等
/// legado 核心特性是否正常工作。
///
/// 之前因 `bookUrl: /novels/api/book/{{$.book_id}}` 被 RuleParser 误判为
/// XPath，导致搜索结果全部被跳过；tocUrl / chapterUrl 同理。
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

  /// 酷我小说书源配置（从 xiu2_sources.json 录制）。
  /// 关键点：bookUrl / tocUrl / chapterUrl 都用 {{$.path}} 模板。
  final source = BookSource(
    bookSourceName: '酷我小说',
    bookSourceUrl: 'http://appi.kuwo.cn',
    bookSourceType: BookSourceType.text,
    searchUrl: '/novels/api/book/search?keyword={{key}}&pi={{page}}&ps=30',
    ruleSearch: const RuleSearch(
      bookList: '\$.data',
      name: '\$.title',
      author: '\$.author_name',
      coverUrl: '\$.cover_url',
      intro: '\$.intro',
      wordCount: '\$.all_words',
      bookUrl: '/novels/api/book/{{\$.book_id}}',
    ),
    ruleBookInfo: const RuleBookInfo(
      name: '\$.title',
      author: '\$.author_name',
      intro: '\$.intro',
      coverUrl: '\$.cover_url',
      wordCount: '\$.all_words',
      lastChapter: '\$.new_chapter_name',
      tocUrl: '/novels/api/book/{{\$.book_id}}/chapters?paging=0',
    ),
    ruleToc: const RuleToc(
      chapterList: '\$.data',
      chapterName: '\$.chapter_title',
      chapterUrl: '/novels/api/book/{{\$.book_id}}/chapters/{{\$.chapter_id}}',
    ),
    ruleContent: const RuleContent(
      content: '\$.data.content',
    ),
  );

  /// 搜索「三体」的真实响应（已裁剪）。
  const searchResponse = '''
{"code":200,"data":[{"book_id":"21041885901615104","title":"三体：史上最称职的面壁者","author_name":"火炀","cover_url":"https://openbookcover.yuewen.com/c_21041885901615104","intro":"姜宇：面壁计划还没有开始，我就已经是面壁人。","all_words":1400896,"new_chapter_name":"新书发布","category_name":"诸天无限","status":50}],"message":"success"}
''';

  /// 书籍详情真实响应（已裁剪）。
  /// 注意：实际字段在 `data` 对象下，规则用 `$.title` 而非 `$.data.title`，
  /// 依赖 BookInfoFetcher 的 init 解包逻辑。
  const bookDetailResponse = '''
{"code":200,"data":{"book_id":"21041885901615104","title":"三体：史上最称职的面壁者","author_name":"火炀","cover_url":"https://openbookcover.yuewen.com/c_21041885901615104","intro":"姜宇：面壁计划还没有开始，我就已经是面壁人。","all_words":1400896,"new_chapter_name":"新书发布","category_name":"诸天无限","status":50}}
''';

  /// 目录真实响应（已裁剪到前 3 章）。
  const tocResponse = '''
{"code":200,"data":[{"book_id":"21041885901615104","chapter_id":"56483893775675668","chapter_title":"第一章：欺瞒计划","volume_name":"第1卷"},{"book_id":"21041885901615104","chapter_id":"56493803758395263","chapter_title":"第二章：展开","volume_name":"第1卷"},{"book_id":"21041885901615104","chapter_id":"56506348015685049","chapter_title":"第三章：毒苹果计划","volume_name":"第1卷"}]}
''';

  /// 正文真实响应（已裁剪）。
  const contentResponse = '''
{"code":200,"data":{"content":"姜宇在一个没人的教室虔诚地小声祈祷：主，伊文斯过于偏激，叶文洁空有统帅头衔，他们都难成大事。"}}
''';

  setUp(() {
    engine = RuleEngine();
  });

  group('酷我小说端到端（真实 API 响应）', () {
    test('搜索：{{\$.book_id}} 模板替换 → 拿到 bookUrl', () async {
      final fetcher = _FakeFetcher({
        'http://appi.kuwo.cn/novels/api/book/search?keyword=%E4%B8%89%E4%BD%93&pi=1&ps=30':
            searchResponse,
      });
      final searcher = SingleSourceSearcher(fetcher: fetcher, ruleEngine: engine);

      final results = await searcher.search('三体', source);

      expect(results.length, 1);
      expect(results[0].bookName, '三体：史上最称职的面壁者');
      expect(results[0].author, '火炀');
      // 关键断言：bookUrl 模板被正确替换，不再是 {{$.book_id}}
      expect(results[0].sources.first.bookUrl,
          'http://appi.kuwo.cn/novels/api/book/21041885901615104');
    });

    test('详情：init 解包 + tocUrl 模板替换', () async {
      final fetcher = _FakeFetcher({
        'http://appi.kuwo.cn/novels/api/book/21041885901615104':
            bookDetailResponse,
      });
      final infoFetcher =
          BookInfoFetcher(fetcher: fetcher, ruleEngine: engine);

      final info = await infoFetcher.fetch(
        'http://appi.kuwo.cn/novels/api/book/21041885901615104',
        source,
      );

      // init 解包后 $.title 能拿到值
      expect(info.name, '三体：史上最称职的面壁者');
      expect(info.author, '火炀');
      // 关键断言：tocUrl 模板被正确替换
      expect(info.tocUrl,
          'http://appi.kuwo.cn/novels/api/book/21041885901615104/chapters?paging=0');
    });

    test('目录：chapterUrl 双模板替换（book_id + chapter_id）', () async {
      final fetcher = _FakeFetcher({
        'http://appi.kuwo.cn/novels/api/book/21041885901615104/chapters?paging=0':
            tocResponse,
      });
      final tocFetcher = TocFetcher(fetcher: fetcher, ruleEngine: engine);

      final chapters = await tocFetcher.fetch(
        'http://appi.kuwo.cn/novels/api/book/21041885901615104/chapters?paging=0',
        source,
      );

      expect(chapters.length, 3);
      expect(chapters[0].name, '第一章：欺瞒计划');
      // 关键断言：chapterUrl 含两个模板，都被正确替换
      expect(chapters[0].url,
          'http://appi.kuwo.cn/novels/api/book/21041885901615104/chapters/56483893775675668');
      expect(chapters[2].name, '第三章：毒苹果计划');
      expect(chapters[2].url,
          'http://appi.kuwo.cn/novels/api/book/21041885901615104/chapters/56506348015685049');
    });

    test('正文：\$.data.content JSONPath 提取', () async {
      final fetcher = _FakeFetcher({
        'http://appi.kuwo.cn/novels/api/book/21041885901615104/chapters/56483893775675668':
            contentResponse,
      });
      // ContentFetcher 直接用 RuleEngine.eval 提取 content 字段
      final content = engine.eval(contentResponse, '\$.data.content');
      expect(content, isNotNull);
      expect(content!.contains('姜宇'), isTrue);
    });
  });
}
