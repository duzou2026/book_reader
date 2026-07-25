import 'package:book_reader/app/providers.dart';
import 'package:book_reader/domain/usecases/discover_books.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 发现/排行页：按分类展示热门书榜。
///
/// - 顶部横向滚动的分类 Tab，点击切换。
/// - 列表按多源覆盖数倒序（视为热度信号）。
/// - 显示封面、书名、作者、源覆盖数、简介。
/// - 拉取过程展示进度条 + 各源状态。
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  DiscoverCategory _selected = DiscoverCategories.all.first;
  List<SearchResult> _results = const [];
  bool _loading = false;
  String? _error;
  int _completed = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
      _completed = 0;
      _total = 0;
    });
    try {
      final list = await ref.read(discoverBooksProvider).fetch(
        _selected,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _completed = p.completed;
            _total = p.total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _openBook(SearchResult r) {
    context.go('/book', extra: r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // 分类条
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: DiscoverCategories.all.length,
              itemBuilder: (context, i) {
                final c = DiscoverCategories.all[i];
                final selected = c.id == _selected.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${c.emoji} ${c.name}'),
                    selected: selected,
                    onSelected: (_) {
                      if (selected) return;
                      setState(() => _selected = c);
                      _load();
                    },
                  ),
                );
              },
            ),
          ),
          // 进度条
          if (_loading && _total > 0)
            LinearProgressIndicator(
              value: _completed / _total,
              minHeight: 2,
              backgroundColor: ThemeColors.surfaceLevel2(context),
            ),
          // 状态行
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('$_completed / $_total 源已返回，已聚合 ${_results.length} 本',
                      style: TextStyle(fontSize: 12, color: ThemeColors.mutedText(context))),
                ],
              ),
            ),
          // 列表
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const Center(child: Text('正在从多源聚合榜单...'));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 64, color: ThemeColors.mutedText(context)),
            const SizedBox(height: 12),
            const Text('该分类暂无结果'),
            const SizedBox(height: 6),
            Text('请确认已导入并启用书源',
                style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/book-sources'),
              icon: const Icon(Icons.library_books),
              label: const Text('去书源管理'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) => _BookRankTile(
          rank: i + 1,
          result: _results[i],
          onTap: () => _openBook(_results[i]),
        ),
      ),
    );
  }
}

class _BookRankTile extends StatelessWidget {
  final int rank;
  final SearchResult result;
  final VoidCallback onTap;

  const _BookRankTile({
    required this.rank,
    required this.result,
    required this.onTap,
  });

  Color _rankColor(BuildContext context) {
    if (rank == 1) return const Color(0xFFE53935);
    if (rank == 2) return const Color(0xFFFB8C00);
    if (rank == 3) return const Color(0xFFFDD835);
    return ThemeColors.mutedText(context);
  }

  @override
  Widget build(BuildContext context) {
    final cover = result.coverUrl;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _rankColor(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          cover != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    cover,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _placeholder(context, 50, 70),
                  ),
                )
              : _placeholder(context, 50, 70),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              result.bookName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${result.sources.length} 源',
              style: const TextStyle(fontSize: 10, color: Colors.teal),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            result.author,
            style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (result.intro != null && result.intro!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              result.intro!,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (result.kind != null && result.kind!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: result.kind!
                  .split(RegExp(r'[,，、\s]+'))
                  .where((s) => s.trim().isNotEmpty)
                  .take(3)
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(t.trim(),
                            style: const TextStyle(fontSize: 10)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _placeholder(BuildContext context, double w, double h) {
    return Container(
      width: w,
      height: h,
      color: ThemeColors.surfaceLevel2(context),
      child: const Icon(Icons.book, color: Colors.white54),
    );
  }
}
