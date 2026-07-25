import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/data/reading_history_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 阅读历史页：列出所有打开过的书（独立于书架）。
///
/// - 按「每本书最近一次」聚合，避免重复。
/// - 顶部 Tab 切换「按书聚合 / 全部记录」两种视图。
/// - 支持清空全部历史、删除单条历史。
class ReadingHistoryPage extends ConsumerStatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  ConsumerState<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends ConsumerState<ReadingHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Future<List<ReadingHistoryEntry>>? _futurePerBook;
  Future<List<ReadingHistoryEntry>>? _futureAll;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    final repo = ref.read(readingHistoryRepositoryProvider);
    _futurePerBook = repo.getRecentPerBook();
    _futureAll = repo.getAll();
    setState(() {});
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空阅读历史'),
        content: const Text('将清除所有阅读历史记录，书架与统计不受影响。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(readingHistoryRepositoryProvider).clear();
    _reload();
  }

  Future<void> _deleteOne(ReadingHistoryEntry e) async {
    await ref.read(readingHistoryRepositoryProvider).delete(e.id);
    _reload();
  }

  Future<void> _deleteByBook(ReadingHistoryEntry e) async {
    await ref.read(readingHistoryRepositoryProvider).deleteByBook(e.bookId);
    _reload();
  }

  void _openBook(ReadingHistoryEntry e) {
    final sr = SearchResult(
      bookName: e.bookName,
      author: e.author,
      coverUrl: e.coverUrl,
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

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '$m 分 $s 秒';
    final h = m ~/ 60;
    final mm = m % 60;
    return '$h 时 $mm 分';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空历史',
            onPressed: _clearAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '按书聚合'),
            Tab(text: '全部记录'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_futurePerBook, perBook: true),
          _buildList(_futureAll, perBook: false),
        ],
      ),
    );
  }

  Widget _buildList(Future<List<ReadingHistoryEntry>>? future,
      {required bool perBook}) {
    return FutureBuilder<List<ReadingHistoryEntry>>(
      future: future,
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
                const Icon(Icons.history, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('暂无阅读历史'),
                const SizedBox(height: 6),
                const Text('阅读任意章节后会在此显示',
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
          onRefresh: () async => _reload(),
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
                  if (!perBook) return true;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('删除该书历史'),
                      content: Text(
                          '将删除《${e.bookName}》的所有阅读历史，确认？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  return ok ?? false;
                },
                onDismissed: (_) =>
                    perBook ? _deleteByBook(e) : _deleteOne(e),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
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
                        _formatTime(e.readAt),
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
                        '${e.author} · ${e.sourceName}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '读到：${e.chapterName}',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '阅读 ${_formatDuration(e.durationSeconds)}',
                        style: const TextStyle(
                            color: Colors.teal, fontSize: 11),
                      ),
                    ],
                  ),
                  onTap: () => _openBook(e),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade300,
      child: const Icon(Icons.book, color: Colors.white54),
    );
  }
}
