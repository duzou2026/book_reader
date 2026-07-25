/// 推荐导入的真实书源 JSON（legado 兼容格式）。
///
/// 与 [RemoteBookSources] 的关系：
/// - [RemoteBookSources] 从 GitHub 仓库拉取完整书源列表（约 26 条）
/// - 此常量是「书源管理页 → 导入推荐书源」按钮使用的 JSON 字符串
///   作为离线兜底（用户断网时也能手动导入 2 条精简版）
///
/// 这里只放一份精简版，完整版见仓库 `book_sources/xiu2_sources.json`。
const String recommendedBookSourceJson = r'''
[
  {
    "bookSourceName": "铅笔小说",
    "bookSourceUrl": "https://www.23qb.com",
    "bookSourceType": 0,
    "enabled": true,
    "bookSourceGroup": "推荐",
    "searchUrl": "/search.html?searchkey={{key}}",
    "ruleSearch": {
      "bookList": "class.module-search-item",
      "bookUrl": "tag.a.0@href",
      "coverUrl": "tag.img.0@data-src",
      "intro": "class.novel-info-item.0@text",
      "kind": "class.tag-link.0@tag.span.0@text## ##,",
      "name": "tag.a.0@title"
    },
    "ruleBookInfo": {
      "author": "//meta[@property='og:novel:author']/@content",
      "coverUrl": "//meta[@property='og:image']/@content",
      "intro": "//meta[@property='og:description']/@content",
      "kind": "//meta[@property='og:novel:tags']/@content",
      "lastChapter": "//meta[@property='og:novel:latest_chapter_name']/@content",
      "name": "//meta[@property='og:novel:book_name']/@content",
      "tocUrl": "class.catalog-more.0@href",
      "wordCount": "class.novel-info-aux.0@tag.span.-1@text"
    },
    "ruleToc": {
      "chapterList": "class.module-row-text",
      "chapterName": "tag.span.0@text",
      "chapterUrl": "href"
    },
    "ruleContent": {
      "content": "class.article-content.0@html##\\(本章完\\)"
    }
  },
  {
    "bookSourceName": "八一中文",
    "bookSourceUrl": "https://www.81zw2.com",
    "bookSourceType": 0,
    "enabled": true,
    "bookSourceGroup": "推荐",
    "searchUrl": "https://www.81zw2.com/s.php?q={{key}}",
    "ruleSearch": {
      "bookList": "css:.book-list > li",
      "name": "css:.book-name@text",
      "author": "css:.author@text",
      "bookUrl": "css:a@href"
    }
  }
]
''';
