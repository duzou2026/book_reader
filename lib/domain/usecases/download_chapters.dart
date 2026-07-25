import 'package:book_reader/data/chapter_cache_repository.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/domain/usecases/get_chapter_content.dart';
import 'package:book_reader/services/book_info/content_validator.dart';

/// 「批量下载章节到缓存」用例 (E-1)。
///
/// 给定 [BookInfo] + 章节列表 + 范围，逐个抓取正文并写入 [ChapterCacheRepository]。
/// 跳过已缓存章节（避免重复请求）；遇到 VIP / 无效正文也跳过但不中断。
/// 通过 [onProgress] 报告进度，便于 UI 展示进度条。
class DownloadChapters {
  final GetChapterContent _getContent;
  final ChapterCacheRepository _cache;

  DownloadChapters({
    required GetChapterContent getContent,
    required ChapterCacheRepository cache,
  })  : _getContent = getContent,
        _cache = cache;

  /// 下载 [chapters] 中 [start, end] 闭区间内的章节到缓存。
  ///
  /// [bookUrl] 用于缓存 key；[sourceUrl] 用于按源失效。
  /// 返回成功缓存的章节数（不含已缓存和失败的）。
  Future<int> call({
    required BookInfo book,
    required List<Chapter> chapters,
    required int start,
    required int end,
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    final lo = start.clamp(0, chapters.length - 1);
    final hi = end.clamp(lo, chapters.length - 1);
    final total = hi - lo + 1;
    var completed = 0;
    var succeeded = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = lo; i <= hi; i++) {
      final c = chapters[i];
      final key = ChapterCacheRepository.makeKey(book.url, c.url);
      if (_cache.has(book.url, c.url)) {
        skipped++;
        completed++;
        onProgress?.call(DownloadProgress(
          completed: completed,
          total: total,
          succeeded: succeeded,
          skipped: skipped,
          failed: failed,
          current: c.name,
        ));
        continue;
      }
      try {
        final content = await _getContent(book, c);
        if (!ContentValidator.isValid(content)) {
          failed++;
        } else {
          await _cache.put(CachedChapter(
            key: key,
            bookUrl: book.url,
            content: content,
            chapterName: c.name,
            chapterIndex: c.index,
            cachedAt: DateTime.now().millisecondsSinceEpoch,
            sourceUrl: book.sourceUrl,
          ));
          succeeded++;
        }
      } catch (_) {
        failed++;
      }
      completed++;
      onProgress?.call(DownloadProgress(
        completed: completed,
        total: total,
        succeeded: succeeded,
        skipped: skipped,
        failed: failed,
        current: c.name,
      ));
    }
    return succeeded;
  }
}

/// 下载进度。
class DownloadProgress {
  final int completed;
  final int total;
  final int succeeded;
  final int skipped;
  final int failed;
  final String current;

  const DownloadProgress({
    required this.completed,
    required this.total,
    required this.succeeded,
    required this.skipped,
    required this.failed,
    required this.current,
  });

  double get ratio => total == 0 ? 0.0 : completed / total;
}
