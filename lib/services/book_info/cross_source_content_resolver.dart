import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
import 'package:book_reader/services/book_info/content_validator.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';

/// 跨书源章节回退解析器。
///
/// 当原书源某章正文获取失败或为 VIP 时，依次尝试备选书源：
///   1. 在备选源的目录里按章节名模糊匹配找到对应章节
///   2. 抓取该章节正文
///   3. 校验正文有效性（非空、非付费提示）
/// 按书源在 [alternatives] 列表中的顺序优先返回第一个成功的源。
class CrossSourceContentResolver {
  final TocFetcher tocFetcher;
  final ContentFetcher contentFetcher;
  final Future<List<BookSource>> Function() _getEnabledSources;

  CrossSourceContentResolver({
    required this.tocFetcher,
    required this.contentFetcher,
    required Future<List<BookSource>> Function() getEnabledSources,
  }) : _getEnabledSources = getEnabledSources;

  /// 尝试在 [alternatives] 中找到 [chapter] 的可用替代源。
  ///
  /// [alternatives] 应按优先级排序，函数会按顺序尝试，返回第一个成功的。
  /// 失败返回 null。
  Future<ResolvedChapter?> resolve({
    required Chapter chapter,
    required List<BookInfo> alternatives,
  }) async {
    if (alternatives.isEmpty) return null;
    final sources = await _getEnabledSources();
    final byUrl = {for (final s in sources) s.bookSourceUrl: s};

    for (final alt in alternatives) {
      final source = byUrl[alt.sourceUrl];
      if (source == null) continue;

      // 1. 在备选源抓目录
      final List<Chapter> altToc;
      try {
        altToc = await tocFetcher.fetch(alt.tocUrl ?? alt.url, source);
      } catch (_) {
        continue;
      }
      if (altToc.isEmpty) continue;

      // 2. 按章节名模糊匹配
      final matched = _matchChapter(chapter, altToc);
      if (matched == null) continue;

      // 3. 抓正文
      final String content;
      try {
        content = await contentFetcher.fetch(matched.url, source);
      } catch (_) {
        continue;
      }

      // 4. 校验有效性
      if (!ContentValidator.isValid(content)) continue;

      return ResolvedChapter(
        sourceInfo: alt,
        chapter: matched,
        content: content,
        sourceToc: altToc,
      );
    }
    return null;
  }

  /// 模糊匹配章节：归一化后比较名字。
  ///
  /// 归一化规则：去空白、去常见标点、转小写。
  /// 支持子串匹配（备选源章节名包含目标名，或反之）。
  Chapter? _matchChapter(Chapter target, List<Chapter> toc) {
    final targetName = _normalize(target.name);
    if (targetName.isEmpty) return null;

    // 精确匹配优先
    for (final c in toc) {
      if (_normalize(c.name) == targetName) return c;
    }
    // 子串匹配（处理"第十章" vs "第10章"等差异）
    for (final c in toc) {
      final n = _normalize(c.name);
      if (n.isEmpty) continue;
      if (n.contains(targetName) || targetName.contains(n)) return c;
    }
    return null;
  }

  String _normalize(String s) {
    return s
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[，。、,.\[\]【】()（）]'), '')
        .toLowerCase();
  }
}

/// 解析结果：包含切换后的源信息 + 章节信息 + 正文 + 完整目录。
///
/// [sourceToc] 用于切换源后继续阅读后续章节（1G-T4）。
class ResolvedChapter {
  final BookInfo sourceInfo;
  final Chapter chapter;
  final String content;
  final List<Chapter> sourceToc;
  const ResolvedChapter({
    required this.sourceInfo,
    required this.chapter,
    required this.content,
    required this.sourceToc,
  });
}
