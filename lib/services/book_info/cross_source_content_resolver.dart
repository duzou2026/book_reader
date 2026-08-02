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

  /// 模糊匹配章节：归一化后比较名字，并结合章节序号提高准确率。
  ///
  /// 匹配优先级：
  ///   1. 章节序号精确匹配（从章节名解析的数字，如"第十章"→10）
  ///   2. 章节名归一化后精确匹配
  ///   3. 章节名子串匹配
  ///   4. 序号相近 + 名字部分匹配（容错）
  Chapter? _matchChapter(Chapter target, List<Chapter> toc) {
    final targetName = _normalize(target.name);
    final targetIndex = _parseChapterIndex(target.name);
    if (targetName.isEmpty && targetIndex == null) return null;

    // 收集所有候选及评分
    final candidates = <_ChapterCandidate>[];

    for (int i = 0; i < toc.length; i++) {
      final c = toc[i];
      if (c.isVolume) continue;

      final cName = _normalize(c.name);
      final cIndex = _parseChapterIndex(c.name);

      int score = 0;

      // 序号精确匹配（最高优先级）
      if (targetIndex != null && cIndex != null && targetIndex == cIndex) {
        score += 100;
      }
      // 序号接近（相差 ≤ 2），作为弱信号
      if (targetIndex != null && cIndex != null) {
        final diff = (targetIndex - cIndex).abs();
        if (diff == 1) score += 10;
        else if (diff == 2) score += 5;
      }
      // 名字精确匹配
      if (cName.isNotEmpty && cName == targetName) {
        score += 80;
      }
      // 名字子串匹配
      else if (cName.isNotEmpty && targetName.isNotEmpty) {
        if (cName.contains(targetName) || targetName.contains(cName)) {
          score += 40;
        }
      }
      // 备选源目录位置接近（目标章节索引在列表中的位置相近）
      if (target.index > 0 && c.index > 0) {
        final posDiff = (target.index - c.index).abs();
        if (posDiff == 0) score += 15;
        else if (posDiff <= 2) score += 8;
        else if (posDiff <= 5) score += 3;
      }

      if (score > 0) {
        candidates.add(_ChapterCandidate(c, score));
      }
    }

    if (candidates.isEmpty) return null;

    // 按分数降序排序，取最高分
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 最低及格分：30（避免弱匹配误判）
    if (candidates.first.score < 30) return null;

    return candidates.first.chapter;
  }

  /// 从章节名中解析数字序号。
  ///
  /// 支持格式：
  ///   - "第一章" → 1
  ///   - "第123章" → 123
  ///   - "第 123 章 标题" → 123
  ///   - "123. 标题" → 123
  ///   - "123、标题" → 123
  ///   - "第一百二十三章" → 123（中文数字）
  int? _parseChapterIndex(String name) {
    if (name.isEmpty) return null;

    // 匹配 "第xxx章" 格式（阿拉伯数字）
    final nMatch = RegExp(r'第\s*(\d+)\s*[章节回话节]').firstMatch(name);
    if (nMatch != null) {
      return int.tryParse(nMatch.group(1)!);
    }

    // 匹配 "第xxx章" 格式（中文数字）
    final cMatch = RegExp(r'第\s*([零〇一二三四五六七八九十百千万两]+)\s*[章节回话节]').firstMatch(name);
    if (cMatch != null) {
      return _chineseNumberToInt(cMatch.group(1)!);
    }

    // 匹配 "123." 或 "123、" 开头
    final pMatch = RegExp(r'^\s*(\d+)\s*[.、\s]').firstMatch(name);
    if (pMatch != null) {
      return int.tryParse(pMatch.group(1)!);
    }

    return null;
  }

  static const _cnDigitMap = <String, int>{
    '零': 0, '〇': 0,
    '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
  };
  static const _cnUnitMap = <String, int>{
    '十': 10, '百': 100, '千': 1000, '万': 10000,
  };

  /// 中文数字转整数（支持到万以内，如"一百二十三"→123）。
  int? _chineseNumberToInt(String s) {
    if (s.isEmpty) return null;
    int total = 0;
    int current = 0;
    bool hasUnit = false;

    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (_cnDigitMap.containsKey(ch)) {
        current = _cnDigitMap[ch]!;
        if (i == s.length - 1) total += current;
      } else if (_cnUnitMap.containsKey(ch)) {
        final unit = _cnUnitMap[ch]!;
        if (current == 0) current = 1; // "十三" → 13
        total += current * unit;
        current = 0;
        hasUnit = true;
      }
    }
    if (!hasUnit && current > 0) return current; // 单个数字
    return total > 0 ? total : null;
  }

  String _normalize(String s) {
    return s
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[，。、,.\[\]【】()（）]'), '')
        .toLowerCase();
  }
}

/// 章节匹配候选，用于评分排序。
class _ChapterCandidate {
  final Chapter chapter;
  final int score;
  _ChapterCandidate(this.chapter, this.score);
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
