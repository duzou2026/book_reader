import 'dart:convert';

import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/demo_book_sources.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/domain/usecases/test_book_source.dart';
import 'package:book_reader/services/book_source/book_source_importer.dart';
import 'package:book_reader/ui/book_sources/book_source_import_dialog.dart';
import 'package:book_reader/ui/book_sources/book_source_test_sheet.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 书源管理页（禁止使用公开书源，详见 MEMORY.md）。
///
/// 书源来源：
/// - 内置定制书源：[recommendedBookSourceJson] 常量中的用户定制书源
/// - 用户手动添加/粘贴的书源
///
/// 「刷新书源」按钮已改为重新导入内置定制书源。
/// 「导入推荐书源」按钮导入内置定制书源（歪歪小说网等用户指定书源）。

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

  /// 当前分组筛选（null = 全部，'' = 未分组）。
  String? _selectedGroup;

  /// 状态筛选：null=全部，true=仅启用，false=仅禁用。
  bool? _statusFilter;

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

  /// 一键导入内置定制书源 JSON（legado 兼容格式）。
  ///
  /// 与「粘贴 JSON 导入」对话框的区别：
  /// - 这里直接使用 [recommendedBookSourceJson] 中的用户定制书源
  Future<void> _importRecommended() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入内置定制书源', style: TextStyle(fontSize: 16)),
        content: const Text(
          '将导入用户定制的书源（歪歪小说网等），导入后可在书源管理页编辑。',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final sources = BookSourceImporter()
          .parse(recommendedBookSourceJson, throwOnInvalid: false);
      final repo = ref.read(bookSourceRepositoryProvider);
      for (final s in sources) {
        await repo.upsert(s);
      }
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${sources.length} 个定制书源')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  /// 从远程仓库刷新用户定制书源（禁止使用 legado 公开书源，详见 MEMORY.md）。
  ///
  /// - 从 GitHub/Gitee 仓库 `book_sources/custom_sources.json` 拉取
  /// - 已有同 URL 的会被覆盖
  Future<void> _refreshRemoteSources() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在同步云端定制书源...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final fetcher = ref.read(remoteBookSourcesProvider);
      final sources = await fetcher.fetch(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未拉取到定制书源，请检查网络')),
        );
        return;
      }
      final repo = ref.read(bookSourceRepositoryProvider);
      for (final s in sources) {
        await repo.upsert(s);
      }
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已同步 ${sources.length} 个定制书源')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步失败：$e')),
      );
    }
  }

  Future<void> _openEdit([BookSource? initial]) async {
    final saved = await context.push<bool>(
      '/book-source-edit',
      extra: initial,
    );
    if (saved == true && mounted) {
      setState(_reload);
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

  /// 一键测速：并发测试所有已启用书源（最多 8 并发），
  /// 完成后显示结果汇总，支持一键禁用失败源。
  Future<void> _batchTestSources() async {
    if (_batchTesting) return;
    final enabled = _lastList.where((s) => s.enabled).toList();
    if (enabled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有已启用的书源')),
      );
      return;
    }
    setState(() {
      _batchTesting = true;
      _batchTestCompleted = 0;
      _batchTestTotal = enabled.length;
      _batchTestResults.clear();
    });

    final tester = ref.read(testBookSourceProvider);
    const concurrency = 8;
    var index = 0;

    Future<void> worker() async {
      while (true) {
        int? idx;
        if (mounted) {
          setState(() {
            if (index < enabled.length) {
              idx = index++;
            }
          });
        }
        if (idx == null) break;
        final source = enabled[idx!];
        try {
          final result = await tester.call(source).timeout(
            const Duration(seconds: 45),
          );
          if (mounted) {
            setState(() {
              _batchTestResults[source.bookSourceUrl] = result.overallStatus;
              _batchTestCompleted++;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _batchTestResults[source.bookSourceUrl] = TestOverallStatus.fail;
              _batchTestCompleted++;
            });
          }
        }
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, enabled.length),
      (_) => worker(),
    );
    await Future.wait(workers);

    if (!mounted) return;
    setState(() => _batchTesting = false);

    final ok = _batchTestResults.values
        .where((s) => s == TestOverallStatus.ok)
        .length;
    final partial = _batchTestResults.values
        .where((s) => s == TestOverallStatus.partial)
        .length;
    final fail = _batchTestResults.values
        .where((s) => s == TestOverallStatus.fail)
        .length;

    // 显示结果对话框
    final disableFails = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('测速完成', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultRow('✅ 全部通过', ok, Colors.green),
            _resultRow('⚠️ 部分通过', partial, Colors.orange),
            _resultRow('❌ 失败', fail, Colors.red),
            const SizedBox(height: 12),
            Text(
              '共测试 ${_batchTestTotal} 个书源',
              style: TextStyle(color: ThemeColors.mutedText(ctx), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('关闭'),
          ),
          if (fail > 0)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('一键禁用 $fail 个失败源'),
            ),
        ],
      ),
    );

    if (disableFails == true && mounted) {
      final repo = ref.read(bookSourceRepositoryProvider);
      var count = 0;
      for (final s in enabled) {
        if (_batchTestResults[s.bookSourceUrl] == TestOverallStatus.fail) {
          await repo.setEnabled(s.bookSourceUrl, false);
          count++;
        }
      }
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已禁用 $count 个失败书源')),
      );
    }
  }

  Widget _resultRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: color)),
          const Spacer(),
          Text('$count',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
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

  /// 导出选中（或全部）书源为 JSON。
  Future<void> _exportSources(List<BookSource> all,
      {bool onlySelected = true}) async {
    final targets = onlySelected
        ? all.where((s) => _selected.contains(s.bookSourceUrl)).toList()
        : all;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的书源')),
      );
      return;
    }
    final json = targets.length == 1
        ? const JsonEncoder.withIndent('  ').convert(targets.first.toJson())
        : const JsonEncoder.withIndent('  ')
            .convert(targets.map((s) => s.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    _exitSelectMode();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('已导出 ${targets.length} 个书源',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('JSON 已复制到剪贴板，可粘贴到导入对话框或分享给他人。',
                  style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeColors.surfaceLevel1(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 批量设置分组。
  Future<void> _batchSetGroup(List<BookSource> all) async {
    final targets = all.where((s) => _selected.contains(s.bookSourceUrl)).toList();
    if (targets.isEmpty) return;
    final groups = all
        .map((s) => s.bookSourceGroup ?? '')
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
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
                    const Text('移动到分组',
                        style: TextStyle(
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
    String? newGroup;
    if (choice == '__new__') {
      final ctrl = TextEditingController();
      newGroup = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('新建分组', style: TextStyle(fontSize: 16)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '输入分组名',
              border: OutlineInputBorder(),
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
                  Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (newGroup == null || newGroup.isEmpty) return;
    } else {
      newGroup = choice;
    }
    final repo = ref.read(bookSourceRepositoryProvider);
    for (final s in targets) {
      await repo.upsert(s.copyWith(
        bookSourceGroup: newGroup.isEmpty ? null : newGroup,
      ));
    }
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已将 ${targets.length} 个书源移动到「${newGroup.isEmpty ? '未分组' : newGroup}」')),
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
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/search');
                  }
                },
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
                  tooltip: '设置分组',
                  icon: const Icon(Icons.folder_outlined),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _batchSetGroup(_lastList),
                ),
                IconButton(
                  tooltip: '导出',
                  icon: const Icon(Icons.ios_share),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _exportSources(_lastList),
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
                  icon: const Icon(Icons.speed_outlined),
                  onPressed: _lastList.isEmpty ? null : _batchTestSources,
                  tooltip: '一键测速',
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () => _openEdit(),
                  tooltip: '新建书源',
                ),
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: _refreshRemoteSources,
                  tooltip: '同步云端定制书源',
                ),
                IconButton(
                  icon: const Icon(Icons.recommend_outlined),
                  onPressed: _importRecommended,
                  tooltip: '导入定制书源',
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _exportSources(_lastList, onlySelected: false),
                  tooltip: '导出全部',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _openImport,
                  tooltip: '粘贴 JSON 导入',
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
                    onPressed: _importRecommended,
                    icon: const Icon(Icons.recommend_outlined),
                    label: const Text('导入定制书源'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _openImport,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('粘贴 JSON 导入'),
                  ),
                ],
              ),
            );
          }
          final list = _filteredList(_lastList);
          final enabledCount = _lastList.where((s) => s.enabled).length;
          // 收集所有分组
          final groups = _lastList
              .map((s) => s.bookSourceGroup ?? '')
              .where((g) => g.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          return Column(
            children: [
              // 批量测速进度条
              if (_batchTesting)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _batchTestTotal == 0
                                ? null
                                : _batchTestCompleted / _batchTestTotal,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '测速中 $_batchTestCompleted/$_batchTestTotal',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
              // 统计 + 搜索框
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('共 ${_lastList.length} 个源',
                        style: TextStyle(
                            color: ThemeColors.mutedText(context), fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('· 已启用 $enabledCount',
                        style: TextStyle(
                            color: ThemeColors.successText(context), fontSize: 13)),
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
              // 状态筛选条
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    _statusChip(null, '全部', _lastList.length),
                    const SizedBox(width: 6),
                    _statusChip(
                        true,
                        '已启用',
                        _lastList.where((s) => s.enabled).length),
                    const SizedBox(width: 6),
                    _statusChip(
                        false,
                        '已禁用',
                        _lastList.where((s) => !s.enabled).length),
                  ],
                ),
              ),
              // 分组筛选条
              if (groups.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    children: [
                      _groupChip(null, '全部', _lastList.length),
                      _groupChip(
                          '',
                          '未分组',
                          _lastList
                              .where((s) =>
                                  (s.bookSourceGroup ?? '').isEmpty)
                              .length),
                      ...groups.map((g) => _groupChip(
                          g,
                          g,
                          _lastList
                              .where((s) => s.bookSourceGroup == g)
                              .length)),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text('没有匹配「$_filter」的书源',
                            style: TextStyle(color: ThemeColors.mutedText(context))),
                      )
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final selected = _selected.contains(s.bookSourceUrl);
                          final testStatus = _testStatusOf(s.bookSourceUrl);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            onLongPress: () => _enterSelectMode(s.bookSourceUrl),
                            onTap: _selectMode
                                ? () => _toggleSelect(s.bookSourceUrl)
                                : () => _openEdit(s),
                            leading: _selectMode
                                ? Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : ThemeColors.mutedText(context),
                                  )
                                : _StatusDot(status: testStatus),
                            title: Text(
                              s.bookSourceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: s.enabled
                                    ? null
                                    : ThemeColors.mutedText(context),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  s.bookSourceUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ThemeColors.mutedText(context),
                                  ),
                                ),
                                if ((s.bookSourceGroup ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(s.bookSourceGroup!,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.teal)),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: _selectMode
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: s.enabled,
                                        onChanged: (v) => _toggle(s, v),
                                      ),
                                      PopupMenuButton<String>(
                                        tooltip: '更多',
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (v) {
                                          switch (v) {
                                            case 'edit':
                                              _openEdit(s);
                                              break;
                                            case 'test':
                                              _testSource(s);
                                              break;
                                            case 'delete':
                                              _delete(s);
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: ListTile(
                                              dense: true,
                                              leading: Icon(
                                                  Icons.edit_outlined),
                                              title: Text('编辑'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'test',
                                            child: ListTile(
                                              dense: true,
                                              leading: Icon(Icons
                                                  .bug_report_outlined),
                                              title: Text('测试'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              dense: true,
                                              leading: Icon(
                                                  Icons.delete_outline),
                                              title: Text('删除'),
                                            ),
                                          ),
                                        ],
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

  /// 批量测速状态。
  bool _batchTesting = false;
  int _batchTestCompleted = 0;
  int _batchTestTotal = 0;
  final Map<String, TestOverallStatus> _batchTestResults = {};

  /// 返回书源最近一次测速状态（无记录返回 null）。
  TestOverallStatus? _testStatusOf(String url) => _batchTestResults[url];

  List<BookSource> _filteredList(List<BookSource> all) {
    var list = all;
    if (_statusFilter != null) {
      list = list.where((s) => s.enabled == _statusFilter).toList();
    }
    if (_selectedGroup != null) {
      if (_selectedGroup!.isEmpty) {
        list = list.where((s) => (s.bookSourceGroup ?? '').isEmpty).toList();
      } else {
        list = list.where((s) => s.bookSourceGroup == _selectedGroup).toList();
      }
    }
    if (_filter.isEmpty) return list;
    final f = _filter.toLowerCase();
    return list
        .where((s) =>
            s.bookSourceName.toLowerCase().contains(f) ||
            s.bookSourceUrl.toLowerCase().contains(f))
        .toList();
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

  Widget _statusChip(bool? key, String label, int count) {
    final selected = _statusFilter == key;
    Color? color;
    if (key == true) color = Colors.green;
    if (key == false) color = Colors.grey;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      selectedColor: color?.withOpacity(0.15),
      checkmarkColor: color,
      onSelected: (_) => setState(() {
        _statusFilter = selected ? null : key;
      }),
    );
  }
}

/// 书源测速状态点：绿=通过，橙=部分通过，红=失败，灰=未测试。
class _StatusDot extends StatelessWidget {
  const _StatusDot({this.status});

  final TestOverallStatus? status;

  @override
  Widget build(BuildContext context) {
    final (color, tooltip) = switch (status) {
      TestOverallStatus.ok => (Colors.green, '测速通过'),
      TestOverallStatus.partial => (Colors.orange, '部分通过'),
      TestOverallStatus.fail => (Colors.red, '测速失败'),
      null => (ThemeColors.mutedText(context).withOpacity(0.4), '未测试'),
    };
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
