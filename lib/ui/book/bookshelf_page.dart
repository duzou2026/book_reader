import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 书架页：本地收藏的书籍列表。
///
/// - 显示所有 [BookshelfEntry]，支持按分组筛选、排序、列表/网格视图切换。
/// - 点击书籍 → 通过最小 [SearchResult] 跳到详情页，详情页会自动重建并续读。
class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  late Future<List<BookshelfEntry>> _future;

  /// 当前分组筛选（null = 全部）。
  String? _selectedGroup;

  /// 当前排序方式。
  BookshelfSort _sort = BookshelfSort.recent;

  /// 当前视图模式。
  BookshelfViewMode _viewMode = BookshelfViewMode.list;

  /// 是否正在检查更新。
  bool _checkingUpdates = false;

  /// 检查更新进度：已处理 / 总数。
  int _checkDone = 0;
  int _checkTotal = 0;

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

  Future<void> _moveToGroup(BookshelfEntry entry, String group) async {
    await ref
        .read(bookshelfRepositoryProvider)
        .updateGroup(id: entry.id, group: group);
    setState(_reload);
  }

  /// 检查整个书架的追更。
  Future<void> _checkUpdates() async {
    if (_checkingUpdates) return;
    setState(() {
      _checkingUpdates = true;
      _checkDone = 0;
      _checkTotal = 0;
    });
    try {
      final updated = await ref.read(checkBookUpdatesProvider).checkAll(
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _checkDone = done;
              _checkTotal = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.isEmpty
              ? '已是最新，暂无更新'
              : '发现 ${updated.length} 本有更新'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _checkingUpdates = false);
      }
    }
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
    context.push('/book', extra: sr);
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

  /// 应用分组筛选与排序。
  List<BookshelfEntry> _applyFilterAndSort(List<BookshelfEntry> src) {
    var list = src.toList();
    if (_selectedGroup != null) {
      if (_selectedGroup!.isEmpty) {
        // 未分组
        list = list.where((e) => e.group.isEmpty).toList();
      } else {
        list = list.where((e) => e.group == _selectedGroup).toList();
      }
    }
    switch (_sort) {
      case BookshelfSort.recent:
        list.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
        break;
      case BookshelfSort.added:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case BookshelfSort.title:
        list.sort((a, b) => a.bookName.compareTo(b.bookName));
        break;
    }
    return list;
  }

  Future<void> _showGroupPicker(BookshelfEntry entry) async {
    final repo = ref.read(bookshelfRepositoryProvider);
    final groups = await repo.getAllGroups();
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 18),
                    const SizedBox(width: 8),
                    Text('移动到分组',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('__new__'),
                      child: const Text('新建分组'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_open, size: 20),
                title: const Text('未分组'),
                onTap: () => Navigator.of(ctx).pop(''),
              ),
              if (groups.isNotEmpty) const Divider(height: 1),
              ...groups.map((g) => ListTile(
                    leading: const Icon(Icons.folder, size: 20),
                    title: Text(g),
                    onTap: () => Navigator.of(ctx).pop(g),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null) return;
    if (choice == '__new__') {
      final newName = await _promptText(
        title: '新建分组',
        hint: '输入分组名',
        initial: '',
      );
      if (newName == null || newName.trim().isEmpty) return;
      await _moveToGroup(entry, newName.trim());
    } else {
      await _moveToGroup(entry, choice);
    }
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    required String initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: _checkingUpdates
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '检查更新',
            onPressed: _checkingUpdates ? null : _checkUpdates,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            tooltip: '排序与视图',
            onSelected: (v) {
              setState(() {
                switch (v) {
                  case 'sort_recent':
                    _sort = BookshelfSort.recent;
                    break;
                  case 'sort_added':
                    _sort = BookshelfSort.added;
                    break;
                  case 'sort_title':
                    _sort = BookshelfSort.title;
                    break;
                  case 'toggle_view':
                    _viewMode = _viewMode == BookshelfViewMode.list
                        ? BookshelfViewMode.grid
                        : BookshelfViewMode.list;
                    break;
                }
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'sort_recent',
                child: Row(children: [
                  Icon(Icons.access_time, size: 18),
                  SizedBox(width: 8),
                  Text('最近阅读'),
                ]),
              ),
              const PopupMenuItem(
                value: 'sort_added',
                child: Row(children: [
                  Icon(Icons.bookmark_add, size: 18),
                  SizedBox(width: 8),
                  Text('加入时间'),
                ]),
              ),
              const PopupMenuItem(
                value: 'sort_title',
                child: Row(children: [
                  Icon(Icons.sort_by_alpha, size: 18),
                  SizedBox(width: 8),
                  Text('书名'),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_view',
                child: Row(children: [
                  Icon(
                    _viewMode == BookshelfViewMode.list
                        ? Icons.grid_view
                        : Icons.view_list,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_viewMode == BookshelfViewMode.list
                      ? '切换到网格视图'
                      : '切换到列表视图'),
                ]),
              ),
            ],
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
          final all = snapshot.data ?? const [];
          if (all.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border,
                      size: 64, color: ThemeColors.mutedText(context)),
                  const SizedBox(height: 12),
                  const Text('书架空空如也'),
                  const SizedBox(height: 6),
                  Text('搜索一本书，从详情页加入书架',
                      style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
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
          // 收集所有分组
          final groups = all
              .map((e) => e.group)
              .where((g) => g.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final list = _applyFilterAndSort(all);
          return Column(
            children: [
              // 检查更新进度条
              if (_checkingUpdates && _checkTotal > 0)
                LinearProgressIndicator(
                  value: _checkDone / _checkTotal,
                  minHeight: 2,
                  backgroundColor: ThemeColors.surfaceLevel2(context),
                ),
              // 分组筛选条
              if (groups.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    children: [
                      _groupChip(null, '全部', all.length),
                      _groupChip('', '未分组',
                          all.where((e) => e.group.isEmpty).length),
                      ...groups.map(
                          (g) => _groupChip(g, g, all.where((e) => e.group == g).length)),
                    ],
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text('该分组下暂无书籍',
                            style: TextStyle(color: ThemeColors.mutedText(context))),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: _viewMode == BookshelfViewMode.list
                            ? _buildListView(list)
                            : _buildGridView(list),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _groupChip(String? key, String label, int count) {
    final selected = _selectedGroup == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() {
          _selectedGroup = selected ? null : key;
        }),
      ),
    );
  }

  Widget _buildListView(List<BookshelfEntry> list) {
    return ListView.separated(
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
                  style: TextStyle(
                      color: ThemeColors.mutedText(context), fontSize: 11),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      e.author,
                      style: TextStyle(
                          color: ThemeColors.mutedText(context), fontSize: 12),
                    ),
                    if (e.group.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(e.group,
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ],
                  ],
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
                if (e.hasUpdate) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.lastChapter != null
                          ? '有更新：${e.lastChapter}'
                          : '有更新',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Icon(Icons.chevron_right, color: ThemeColors.mutedText(context)),
            onTap: () => _openBook(e),
            onLongPress: () => _showEntryMenu(e),
          ),
        );
      },
    );
  }

  Widget _buildGridView(List<BookshelfEntry> list) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        return GestureDetector(
          onTap: () => _openBook(e),
          onLongPress: () => _showEntryMenu(e),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    e.coverUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              e.coverUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _coverPlaceholder(double.infinity, 140),
                            ),
                          )
                        : _coverPlaceholder(double.infinity, 140),
                    if (e.group.isNotEmpty)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(e.group,
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.white)),
                        ),
                      ),
                    if (e.hasUpdate)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('新',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                e.bookName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (e.lastChapterName != null)
                Text(
                  '读到 ${e.lastChapterName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: ThemeColors.mutedText(context)),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEntryMenu(BookshelfEntry e) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(e.bookName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder, size: 20),
              title: Text(e.group.isEmpty ? '设置分组' : '切换分组（当前：${e.group}）'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showGroupPicker(e);
              },
            ),
            if (e.group.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.folder_off, size: 20),
                title: const Text('移出分组'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _moveToGroup(e, '');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 20,
                  color: Colors.red),
              title: const Text('移出书架', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _remove(e);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: ThemeColors.surfaceLevel2(context),
      child: Icon(Icons.book, color: ThemeColors.mutedText(context), size: 24),
    );
  }
}
