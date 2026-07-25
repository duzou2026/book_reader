import 'package:book_reader/data/models/search_result.dart';

/// Mock 兜底搜索数据。
///
/// 当用户搜索时：
/// - 没有任何启用的书源（首次安装未导入书源）
/// - 或所有书源返回空（搜索关键字命中失败）
///
/// 此时返回一份与关键字「相关」的样例结果，让 UI 不至于一片空白，
/// 用户可以看到完整的搜索结果交互（点进详情、加入书架等流程）。
///
/// **重要约定**：
/// - 所有样例结果的 `bookUrl` 都使用 `mock://` 协议前缀
/// - 详情页和阅读器应当能优雅处理 `mock://` URL（不发起网络请求）
/// - 用户可在书源管理页导入真实书源后禁用此兜底行为
class MockSearchFallback {
  const MockSearchFallback();

  /// 根据关键字生成 mock 搜索结果。
  ///
  /// 策略：
  /// - 关键字作为书名的一部分插入若干样例书名
  /// - 作者用预设的中文常见笔名
  /// - 字数/分类/简介用模板拼接
  /// - 始终返回 5~6 条结果，让 UI 演示排序/筛选条
  List<SearchResult> search(String keyword) {
    final kw = keyword.trim();
    if (kw.isEmpty) return const [];

    final authors = [
      '江南',
      '猫腻',
      '烽火戏诸侯',
      '天蚕土豆',
      '辰东',
      '马伯庸',
    ];
    final kinds = [
      '玄幻',
      '历史',
      '科幻',
      '武侠',
      '都市',
      '悬疑',
    ];
    final intros = [
      '少年握紧手中长剑，踏入了风起云涌的乱世。',
      '一座沉睡千年的古城，被无意闯入的旅人唤醒。',
      '当星辰陨落，凡人也能成为传说。',
      '权谋与刀光交织，谁才是真正的棋手？',
      '一段被史书抹去的过往，正在被重新书写。',
      '命运的齿轮悄然转动，所有人都在局中。',
    ];
    final wordCounts = [
      '128.4 万字',
      '235.6 万字',
      '89.2 万字',
      '412.7 万字',
      '67.5 万字',
      '301.8 万字',
    ];
    final lastChapters = [
      '第 1024 章 风起',
      '第 678 章 长夜',
      '第 256 章 残阳',
      '第 1500 章 终章',
      '第 432 章 破晓',
      '第 880 章 归途',
    ];

    final baseTitles = [
      '$kw 之纪',
      '$kw 传奇',
      '$kw 物语',
      '关于 $kw 的二三事',
      '$kw 异闻录',
      '$kw 不眠夜',
    ];

    final results = <SearchResult>[];
    for (var i = 0; i < baseTitles.length; i++) {
      results.add(SearchResult(
        bookName: baseTitles[i],
        author: authors[i % authors.length],
        intro: intros[i % intros.length],
        kind: kinds[i % kinds.length],
        wordCount: wordCounts[i % wordCounts.length],
        lastChapter: lastChapters[i % lastChapters.length],
        sources: [
          SearchSource(
            sourceName: 'Mock 兜底源',
            sourceUrl: 'mock://fallback.local/$i',
            bookUrl: 'mock://fallback.local/$i/book/${_slug(kw)}/$i',
          ),
        ],
      ));
    }
    return results;
  }

  String _slug(String s) {
    return s.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
  }
}
