import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/ui/book_sources/book_source_import_dialog.dart';
import 'package:book_reader/ui/book_sources/book_source_test_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookSourcesPage extends ConsumerStatefulWidget {
  const BookSourcesPage({super.key});

  @override
  ConsumerState<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends ConsumerState<BookSourcesPage> {
  late Future<List<BookSource>> _future;

  /// 是否处于多选模式。
  bool _selectMode = false;

  /// 选中的书源 URL 集合。
  final Set<String> _selected = {};

  /// 搜索过滤词。
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(bookSourceRepositoryProvider).getAll();
  }

  Future<void> _openImport() async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => const BookSourceImportDialog(),
    );
    if (count != null && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 $count 个书源')),
      );
    }
  }

  Future<void> _toggle(BookSource source, bool value) async {
    await ref
        .read(bookSourceRepositoryProvider)
        .setEnabled(source.bookSourceUrl, value);
    setState(_reload);
  }

  Future<void> _delete(BookSource source) async {
    await ref
        .read(bookSourceRepositoryProvider)
        .deleteByUrl(source.bookSourceUrl);
    setState(_reload);
  }

  Future<void> _testSource(BookSource source) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => BookSourceTestSheet(source: source),
    );
    // 测试结束后刷新（测试不修改数据，但保持一致）
    if (mounted) setState(_reload);
  }

  void _enterSelectMode(String url) {
    setState(() {
      _selectMode = true;
      _selected.clear();
      _selected.add(url);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _toggleSelect(String url) {
    setState(() {
      if (_selected.contains(url)) {
        _selected.remove(url);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(url);
      }
    });
  }

  void _selectAll(List<BookSource> list) {
    setState(() {
      _selected
        ..clear()
        ..addAll(list.map((s) => s.bookSourceUrl));
    });
  }

  void _invertSelection(List<BookSource> list) {
    setState(() {
      final all = list.map((s) => s.bookSourceUrl).toSet();
      final inverted = all.difference(_selected);
      _selected
        ..clear()
        ..addAll(inverted);
      if (_selected.isEmpty) _selectMode = false;
    });
  }

  Future<void> _batchSetEnabled(List<BookSource> all, bool enabled) async {
    final repo = ref.read(bookSourceRepositoryProvider);
    final targets = all.where((s) => _selected.contains(s.bookSourceUrl));
    for (final s in targets) {
      await repo.setEnabled(s.bookSourceUrl, enabled);
    }
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已${enabled ? '启用' : '禁用'} ${targets.length} 个书源')),
    );
    _exitSelectMode();
  }

  Future<void> _batchDelete(List<BookSource> all) async {
    final targets = all.where((s) => _selected.contains(s.bookSourceUrl)).toList();
    if (targets.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定删除选中的 ${targets.length} 个书源？此操作不可撤销。'),
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
    if (confirmed != true) return;
    final repo = ref.read(bookSourceRepositoryProvider);
    for (final s in targets) {
      await repo.deleteByUrl(s.bookSourceUrl);
    }
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已删除 ${targets.length} 个书源')),
    );
    _exitSelectMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/search'),
              ),
        title: _selectMode
            ? Text('已选 ${_selected.length} 项')
            : const Text('书源管理'),
        actions: _selectMode
            ? [
                IconButton(
                  tooltip: '全选',
                  icon: const Icon(Icons.select_all),
                  onPressed: () => _selectAll(_filteredList(_lastList)),
                ),
                IconButton(
                  tooltip: '反选',
                  icon: const Icon(Icons.flip_to_back),
                  onPressed: () => _invertSelection(_filteredList(_lastList)),
                ),
                IconButton(
                  tooltip: '启用',
                  icon: const Icon(Icons.visibility),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _batchSetEnabled(_lastList, true),
                ),
                IconButton(
                  tooltip: '禁用',
                  icon: const Icon(Icons.visibility_off),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _batchSetEnabled(_lastList, false),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _batchDelete(_lastList),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _openImport,
                  tooltip: '导入书源',
                ),
              ],
      ),
      body: FutureBuilder<List<BookSource>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          _lastList = snapshot.data ?? const [];
          if (_lastList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有书源'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openImport,
                    icon: const Icon(Icons.add),
                    label: const Text('导入书源'),
                  ),
                ],
              ),
            );
          }
          final list = _filteredList(_lastList);
          final enabledCount = _lastList.where((s) => s.enabled).length;
          return Column(
            children: [
              // 统计 + 搜索框
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('共 ${_lastList.length} 个源',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('· 已启用 $enabledCount',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 13)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _filter = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索书源名称或 URL',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _filter = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text('没有匹配「$_filter」的书源',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final selected = _selected.contains(s.bookSourceUrl);
                          return ListTile(
                            onLongPress: () => _enterSelectMode(s.bookSourceUrl),
                            onTap: _selectMode
                                ? () => _toggleSelect(s.bookSourceUrl)
                                : null,
                            leading: _selectMode
                                ? Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                  )
                                : null,
                            title: Text(s.bookSourceName),
                            subtitle: Text(s.bookSourceUrl,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: _selectMode
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: '测试',
                                        icon: const Icon(Icons.bug_report_outlined,
                                            size: 20),
                                        onPressed: () => _testSource(s),
                                      ),
                                      Switch(
                                        value: s.enabled,
                                        onChanged: (v) => _toggle(s, v),
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.delete_outline),
                                        onPressed: () => _delete(s),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 缓存最近一次加载的全量列表，供 AppBar action 操作使用。
  List<BookSource> _lastList = const [];

  List<BookSource> _filteredList(List<BookSource> all) {
    if (_filter.isEmpty) return all;
    final f = _filter.toLowerCase();
    return all
        .where((s) =>
            s.bookSourceName.toLowerCase().contains(f) ||
            s.bookSourceUrl.toLowerCase().contains(f))
        .toList();
  }
}
