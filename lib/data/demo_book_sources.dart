import 'package:book_reader/data/models/book_source.dart';

/// 内置 demo 书源。
///
/// 这些书源**仅用于首次启动时让 App 不空**：
/// - `enabled = false`：默认不启用，避免被真实搜索请求触发产生错误日志
/// - `bookSourceGroup = 'demo'`：在书源管理页明确分组，方便用户识别/批量删除
/// - 真正可用书源需要用户从「书源管理 → 导入」对话框粘贴 JSON 导入
///
/// 与 [recommendedBookSourceJson] 的关系：
/// - 这里只是「App 内置占位」
/// - `recommendedBookSourceJson` 是「推荐导入的真实书源 JSON 字符串」，
///   可在书源管理页通过对话框粘贴或调用 `importRecommendedSources` 一键导入。
List<BookSource> get demoBookSources => const [
      BookSource(
        bookSourceName: 'Demo · 笔趣阁（示例）',
        bookSourceUrl: 'https://demo-local.example.com/biquge',
        enabled: false,
        bookSourceGroup: 'demo',
        searchUrl:
            'https://demo-local.example.com/biquge/search?q={{key}}',
        ruleSearch: RuleSearch(
          bookList: 'css:.result-list > .item',
          name: 'css:.book-name@text',
          author: 'css:.book-author@text',
          bookUrl: 'css:.book-link@href',
        ),
        ruleBookInfo: RuleBookInfo(
          name: 'css:h1.book-title@text',
          author: 'css:.author@text',
          intro: 'css:.intro@text',
        ),
        ruleToc: RuleToc(
          chapterList: 'css:.chapter-list > li',
          chapterName: 'css:a@text',
          chapterUrl: 'css:a@href',
        ),
        ruleContent: RuleContent(
          content: 'css:.chapter-content@html',
        ),
      ),
      BookSource(
        bookSourceName: 'Demo · 起点中文网（示例）',
        bookSourceUrl: 'https://demo-local.example.com/qidian',
        enabled: false,
        bookSourceGroup: 'demo',
        searchUrl: 'https://demo-local.example.com/qidian/search?kw={{key}}',
        ruleSearch: RuleSearch(
          bookList: 'css:.book-list > .item',
          name: 'css:.book-name@text',
          author: 'css:.author@text',
          bookUrl: 'css:a@href',
        ),
      ),
      BookSource(
        bookSourceName: 'Demo · 番茄小说（示例）',
        bookSourceUrl: 'https://demo-local.example.com/fanqie',
        enabled: false,
        bookSourceGroup: 'demo',
        searchUrl: 'https://demo-local.example.com/fanqie/search?q={{key}}',
        ruleSearch: RuleSearch(
          bookList: 'css:.search-list > .item',
          name: 'css:.title@text',
          author: 'css:.author@text',
          bookUrl: 'css:a@href',
        ),
      ),
    ];

/// 推荐导入的真实书源 JSON（legado 兼容格式）。
///
/// 复制此字符串到「书源管理 → 导入」对话框即可一键导入。
/// 这些是社区维护的常用书源模板，URL 已脱敏为占位符；
/// 用户导入后可在书源管理页编辑具体规则或替换为最新 legado 书源订阅链接。
const String recommendedBookSourceJson = r'''
[
  {
    "bookSourceName": "笔趣阁",
    "bookSourceUrl": "https://www.biquge.com",
    "bookSourceType": 0,
    "enabled": true,
    "bookSourceGroup": "推荐",
    "searchUrl": "https://www.biquge.com/search.php?q={{key}}",
    "ruleSearch": {
      "bookList": "css:.result-list > .item",
      "name": "css:.book-name@text",
      "author": "css:.book-author@text",
      "bookUrl": "css:.book-link@href"
    },
    "ruleBookInfo": {
      "name": "css:h1.book-title@text",
      "author": "css:.author@text",
      "intro": "css:.intro@text"
    },
    "ruleToc": {
      "chapterList": "css:.chapter-list > li",
      "chapterName": "css:a@text",
      "chapterUrl": "css:a@href"
    },
    "ruleContent": {
      "content": "css:.chapter-content@html"
    }
  },
  {
    "bookSourceName": "起点中文网",
    "bookSourceUrl": "https://www.qidian.com",
    "bookSourceType": 0,
    "enabled": true,
    "bookSourceGroup": "推荐",
    "searchUrl": "https://www.qidian.com/search?kw={{key}}",
    "ruleSearch": {
      "bookList": "css:.book-list > .item",
      "name": "css:.book-name@text",
      "author": "css:.author@text",
      "bookUrl": "css:a@href"
    }
  }
]
''';
