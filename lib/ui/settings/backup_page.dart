import 'dart:io';

import 'package:book_reader/app/providers.dart';
import 'package:book_reader/domain/usecases/bookshelf_backup.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _fmtTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String _fmtTimeShort(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 数据备份/恢复页。
///
/// 支持导出全部本地数据（书架、进度、笔记、书签、统计、历史、书源、偏好）
/// 为 JSON 文件，并从备份文件恢复。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  List<File> _backups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exporter = ref.read(exportBookshelfBackupProvider);
      final files = await exporter.listBackupFiles();
      if (!mounted) return;
      setState(() {
        _backups = files.cast<File>();
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

  Future<void> _exportNow() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final exporter = ref.read(exportBookshelfBackupProvider);
      final file = await exporter.exportToFile();
      await _reload();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('已导出：${_basename(file.path)}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreFromFile(File file) async {
    final messenger = ScaffoldMessenger.of(context);
    final exporter = ref.read(exportBookshelfBackupProvider);
    BookshelfBackupData? data;
    try {
      data = await exporter.readFile(file);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('读取备份失败：$e')));
      return;
    }
    if (!mounted) return;

    final confirmed = await _showConfirmDialog(data);
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final restorer = ref.read(restoreBookshelfBackupProvider);
      final summary = await restorer.restore(
        data,
        strategy: RestoreStrategy.overwrite,
      );
      if (!mounted) return;
      _showSummarySheet(summary);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showConfirmDialog(BookshelfBackupData data) {
    final created = DateTime.fromMillisecondsSinceEpoch(data.createdAt);
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认恢复', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('备份时间：${_fmtTimeShort(created)}'),
              const SizedBox(height: 8),
              const Text('将恢复以下数据（覆盖已存在的记录）：',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              _kv('书架', '${data.bookshelf.length} 本'),
              _kv('阅读进度', '${data.readingProgress.length} 条'),
              _kv('笔记', '${data.notes.length} 条'),
              _kv('书签', '${data.bookmarks.length} 条'),
              _kv('阅读统计', '${data.readingStats.length} 天'),
              _kv('阅读历史', '${data.readingHistory.length} 条'),
              _kv('书源', '${data.bookSources.length} 个'),
              if (data.readingPrefs != null) _kv('阅读偏好', '已包含'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('恢复'),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(k,
                style: TextStyle(
                    color: ThemeColors.mutedText(context), fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showSummarySheet(RestoreSummary s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 22),
                    const SizedBox(width: 8),
                    Text('恢复完成',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                _kv('书架', '${s.bookshelfAdded} 新增 · ${s.bookshelfOverwritten} 覆盖'),
                _kv('阅读进度', '${s.progressAdded} 新增 · ${s.progressOverwritten} 覆盖'),
                _kv('笔记', '${s.notesAdded} 新增 · ${s.notesOverwritten} 覆盖'),
                _kv('书签', '${s.bookmarksAdded} 新增 · ${s.bookmarksOverwritten} 覆盖'),
                _kv('阅读统计', '${s.statsAdded} 新增 · ${s.statsOverwritten} 覆盖'),
                _kv('阅读历史', '${s.historyAdded} 条'),
                _kv('书源', '${s.sourcesAdded} 新增 · ${s.sourcesOverwritten} 覆盖'),
                _kv('阅读偏好', s.readingPrefsRestored ? '已恢复' : '未恢复'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('好的'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除备份？', style: TextStyle(fontSize: 16)),
        content: Text('将删除 ${_basename(file.path)}，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final exporter = ref.read(exportBookshelfBackupProvider);
    await exporter.deleteFile(file);
    await _reload();
  }

  String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i < 0 ? path : path.substring(i + 1);
  }

  String _formatTime(File f) {
    try {
      final t = f.statSync().modified;
      return _fmtTime(t);
    } catch (_) {
      return '';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据备份')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 8),
                _buildBackupsList(),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('备份与恢复',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '一键导出书架、阅读进度、笔记、书签、阅读统计、历史、书源和偏好设置。'
              '备份文件保存在 App 私有目录，可在不同设备间通过复制文件迁移。',
              style: TextStyle(
                  color: ThemeColors.mutedText(context), fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _exportNow,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('立即备份'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text('错误：$_error',
                  style: TextStyle(color: ThemeColors.errorText(context), fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackupsList() {
    if (_backups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.folder_off_outlined,
                size: 48, color: ThemeColors.mutedText(context)),
            const SizedBox(height: 8),
            Text('暂无备份文件',
                style: TextStyle(color: ThemeColors.mutedText(context))),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('本地备份 (${_backups.length})',
                style: TextStyle(
                    color: ThemeColors.mutedText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        for (final f in _backups)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: Icon(Icons.description_outlined,
                  color: Theme.of(context).colorScheme.primary),
              title: Text(_basename(f.path),
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                '${_formatTime(f)} · ${_formatSize(f.statSync().size)}',
                style: TextStyle(
                    color: ThemeColors.mutedText(context), fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.restore, size: 20),
                    tooltip: '恢复',
                    onPressed: () => _restoreFromFile(f),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: '删除',
                    onPressed: () => _deleteFile(f),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
