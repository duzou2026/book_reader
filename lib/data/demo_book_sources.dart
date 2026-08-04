/// 用户定制书源 JSON（legado 兼容格式）。
///
/// 重要约定（见 MEMORY.md）：
/// - 禁止使用公开书源，仅使用用户指定提供的定制书源
/// - 此常量为唯一内置默认书源，用户在书源管理页可手动导入
///
/// 当前内置书源：歪歪小说网（http://m.waiwaixs.com）
const String recommendedBookSourceJson = r'''
[
  {
    "bookSourceName": "歪歪小说网",
    "bookSourceUrl": "http://m.waiwaixs.com",
    "bookSourceType": 0,
    "enabled": true,
    "bookSourceGroup": "定制",
    "searchUrl": "http://m.waiwaixs.com/s.php,{\"method\":\"POST\",\"body\":\"s={{key}}&type=articlename\",\"charset\":\"gbk\"}",
    "ruleSearch": {
      "bookList": "p.line",
      "name": "tag.a.0@text",
      "author": "text##.*作者[::]",
      "bookUrl": "tag.a.0@href"
    },
    "ruleBookInfo": {
      "name": "//meta[@property='og:novel:book_name']/@content",
      "author": "//meta[@property='og:novel:author']/@content",
      "coverUrl": "//meta[@property='og:image']/@content",
      "tocUrl": "//meta[@property='og:novel:read_url']/@content",
      "intro": "//meta[@property='og:description']/@content"
    },
    "ruleToc": {
      "chapterList": "ul.chapter li",
      "chapterName": "tag.a.0@text",
      "chapterUrl": "tag.a.0@href"
    },
    "ruleContent": {
      "content": "css:#nr.nr_nr #nr1@html"
    }
  }
]
''';
