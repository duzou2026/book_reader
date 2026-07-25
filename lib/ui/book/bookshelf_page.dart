import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 书架页：本地收藏的书籍列表。
///
/// - 显示所有 [BookshelfEntry]，按最近阅读时间倒序。
/// - 顶部 Tab 切换「书架 / 搜索 / 书源」三页。
/// - 点击书籍 → 通过最小 [SearchResult] 跳到详情页，详情页会自动重建并续读。
class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  late Future<List<BookshelfEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(bookshelfRepositoryProvider).getAll();
  }

  Future<void> _remove(BookshelfEntry entry) async {
    await ref.read(bookshelfRepositoryProvider).delete(entry.id);
    setState(_reload);
  }

  void _openBook(BookshelfEntry e) {
    final sr = SearchResult(
      bookName: e.bookName,
      author: e.author,
      coverUrl: e.coverUrl,
      intro: e.intro,
      kind: e.kind,
      wordCount: e.wordCount,
      lastChapter: e.lastChapter,
      sources: [
        SearchSource(
          sourceName: e.sourceName,
          sourceUrl: e.sourceUrl,
          bookUrl: e.bookUrl,
        ),
      ],
    );
    context.go('/book', extra: sr);
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.month}-${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜书',
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            tooltip: '书源管理',
            onPressed: () => context.go('/book-sources'),
          ),
        ],
      ),
      body: FutureBuilder<List<BookshelfEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('书架空空如也'),
                  const SizedBox(height: 6),
                  const Text('搜索一本书，从详情页加入书架',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/search'),
                    icon: const Icon(Icons.search),
                    label: const Text('去搜书'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = list[i];
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('移出书架'),
                            content: Text('确定将《${e.bookName}》移出书架？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('移出'),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                  },
                  onDismissed: (_) => _remove(e),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: e.coverUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              e.coverUrl!,
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _coverPlaceholder(50, 70),
                            ),
                          )
                        : _coverPlaceholder(50, 70),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.bookName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(e.lastReadAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          e.author,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        if (e.lastChapterName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '读到：${e.lastChapterName}',
                            style: TextStyle(
                              color: Colors.teal.shade700,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _openBook(e),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _coverPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade200,
      child: const Icon(Icons.book, color: Colors.grey, size: 24),
    );
  }
}
