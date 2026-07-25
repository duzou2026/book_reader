import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/domain/usecases/get_book_info.dart';

/// 「检查书架追更」用例。
///
/// 遍历书架中的每一本书，调用 [GetToc] 拉取最新目录，
/// 取最后一章作为「源端最新章节名」，与本地 [BookshelfEntry.lastChapter]
/// 比较以判定是否有更新。
///
/// 单本书失败不影响其他书；调用方可控制并发与超时。
class CheckBookUpdates {
  final GetToc _getToc;
  final BookshelfRepository _repo;

  CheckBookUpdates({
    required GetToc getToc,
    required BookshelfRepository repo,
  })  : _getToc = getToc,
        _repo = repo;

  /// 检查单本书的最新章节名。
  ///
  /// 返回该书的最新章节名（拉取失败时返回 null）。
  /// 成功后会把结果写入 [BookshelfEntry.lastChapter]，便于 UI 展示「有更新」徽标。
  Future<String?> checkOne(BookshelfEntry entry) async {
    try {
      final info = BookInfo(
        url: entry.bookUrl,
        sourceName: entry.sourceName,
        sourceUrl: entry.sourceUrl,
        name: entry.bookName,
        author: entry.author,
      );
      final toc = await _getToc(info);
      if (toc.isEmpty) return null;
      final latest = toc.last.name;
      // 只有变化时才写库，避免无谓 IO
      if (latest != entry.lastChapter) {
        await _repo.updateLatestChapter(id: entry.id, latestChapter: latest);
      }
      return latest;
    } catch (_) {
      return null;
    }
  }

  /// 检查整个书架，返回「有更新」的 bookId 集合。
  ///
  /// [onProgress] 用于回调进度（已处理数 / 总数）。
  Future<Set<String>> checkAll({
    void Function(int done, int total)? onProgress,
  }) async {
    final all = await _repo.getAll();
    final updated = <String>{};
    for (var i = 0; i < all.length; i++) {
      final entry = all[i];
      final latest = await checkOne(entry);
      if (latest != null && latest != entry.lastChapterName) {
        updated.add(entry.id);
      }
      onProgress?.call(i + 1, all.length);
    }
    return updated;
  }
}
