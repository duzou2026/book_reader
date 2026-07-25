import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/domain/usecases/get_chapter_content.dart';
import 'package:book_reader/services/book_info/content_validator.dart';
import 'package:book_reader/services/book_info/cross_source_content_resolver.dart';

/// 「解析章节正文（含跨源回退）」用例。
///
/// 流程：
///   1. 优先从原书源 [book] 抓取正文
///   2. 若正文无效（VIP 占位 / 空 / 错误页）或章节标记为 VIP：
///      调用 [CrossSourceContentResolver] 在 [alternatives] 中寻找可用源
///   3. 返回 [ResolvedContent]：
///      - 若跨源成功，包含切换后的源信息 + 正文 + 完整目录
///      - 若跨源失败，返回原正文（让 UI 兜底显示）
class ResolveChapterContent {
  final GetChapterContent _getContent;
  final CrossSourceContentResolver _resolver;

  ResolveChapterContent({
    required GetChapterContent getContent,
    required CrossSourceContentResolver resolver,
  })  : _getContent = getContent,
        _resolver = resolver;

  Future<ResolvedContent> call({
    required BookInfo book,
    required Chapter chapter,
    required List<BookInfo> alternatives,
  }) async {
    // 1. 抓原源正文（失败不抛错，交给后续判定）
    String originalContent = '';
    try {
      originalContent = await _getContent(book, chapter);
    } catch (_) {
      // 原源抓取失败，继续尝试跨源
    }

    // 2. 判定是否需要跨源回退
    final isVip = ContentValidator.isVip(chapter.isVip, originalContent);
    if (!isVip && ContentValidator.isValid(originalContent)) {
      return ResolvedContent(
        content: originalContent,
        switchedTo: null,
        sourceToc: null,
        isVip: false,
      );
    }

    // 3. 跨源解析
    final resolved = await _resolver.resolve(
      chapter: chapter,
      alternatives: alternatives,
    );

    if (resolved == null) {
      // 跨源也失败：返回原正文（可能是 VIP 提示），让 UI 兜底
      return ResolvedContent(
        content: originalContent,
        switchedTo: null,
        sourceToc: null,
        isVip: true,
      );
    }

    return ResolvedContent(
      content: resolved.content,
      switchedTo: resolved.sourceInfo,
      switchedChapter: resolved.chapter,
      sourceToc: resolved.sourceToc,
      isVip: true,
    );
  }
}

/// 解析结果。
class ResolvedContent {
  /// 最终展示的正文。
  final String content;

  /// 若发生了跨源切换，此处为新源的 [BookInfo]；否则为 null。
  final BookInfo? switchedTo;

  /// 新源中匹配到的章节（仅 [switchedTo] 非空时有意义）。
  final Chapter? switchedChapter;

  /// 新源的完整目录（用于切换后继续阅读后续章节）。
  final List<Chapter>? sourceToc;

  /// 本章是否为 VIP / 无效正文。
  final bool isVip;

  const ResolvedContent({
    required this.content,
    required this.switchedTo,
    required this.sourceToc,
    required this.isVip,
    this.switchedChapter,
  });
}
