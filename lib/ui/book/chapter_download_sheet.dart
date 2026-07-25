import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/domain/usecases/download_chapters.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 章节离线下载 / 缓存管理面板（E-1）。
///
/// 由阅读页 / 详情页共享：
/// - 显示本书已缓存章节数 / 总章节数
/// - 一键缓存本章 / 后 5 章 / 后 10 章 / 全部
/// - 显示下载进度（completed / total，失败计数）
/// - 清除本书缓存
class ChapterDownloadSheet extends ConsumerStatefulWidget {
  final BookInfo book;
  final List<Chapter> chapters;

  /// 调用方当前所在章节序号（用于「缓存本章」与「后 N 章」的起点）。
  /// 详情页调用时传 0。
  final int currentIndex;

  const ChapterDownloadSheet({
    super.key,
    required this.book,
    required this.chapters,
    this.currentIndex = 0,
  });

  /// 以 BottomSheet 形式打开。
  static Future<void> show(
    BuildContext context, {
    required BookInfo book,
    required List<Chapter> chapters,
    int currentIndex = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => ChapterDownloadSheet(
        book: book,
        chapters: chapters,
        currentIndex: currentIndex,
      ),
    );
  }

  @override
  ConsumerState<ChapterDownloadSheet> createState() =>
      _ChapterDownloadSheetState();
}

class _ChapterDownloadSheetState extends ConsumerState<ChapterDownloadSheet> {
  /// 已缓存的章节序号集合（用于列表勾选标记）。
  Set<int> _cachedIndices = {};

  /// 是否正在下载。
  bool _downloading = false;

  /// 下载进度。
  DownloadProgress? _progress;

  /// 已取消标志（下次进度回调时跳过）。
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheStatus();
  }

  Future<void> _refreshCacheStatus() async {
    final repo = ref.read(chapterCacheRepositoryProvider);
    final list = repo.listForBook(widget.book.url);
    if (!mounted) return;
    setState(() {
      _cachedIndices = list.map((c) => c.chapterIndex).toSet();
    });
  }

  /// 启动下载：缓存 [start, end] 闭区间内的章节。
  Future<void> _download(int start, int end, String label) async {
    if (_downloading) return;
    if (widget.chapters.isEmpty) return;
    setState(() {
      _downloading = true;
      _cancelled = false;
      _progress = null;
    });
    try {
      final useCase = ref.read(downloadChaptersProvider);
      await useCase(
        book: widget.book,
        chapters: widget.chapters,
        start: start,
        end: end,
        onProgress: (p) {
          if (_cancelled || !mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      await _refreshCacheStatus();
      if (!_cancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label完成：${_progress?.succeeded ?? 0} 章')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelled = true);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存', style: TextStyle(fontSize: 16)),
        content: const Text('确定清除本书的所有离线缓存？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(chapterCacheRepositoryProvider);
    final n = await repo.deleteForBook(widget.book.url);
    if (!mounted) return;
    await _refreshCacheStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清除 $n 章缓存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.chapters.length;
    final cached = _cachedIndices.length;
    final currentIdx = widget.currentIndex.clamp(0, total - 1);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.download_for_offline, size: 20),
                const SizedBox(width: 8),
                const Text('离线下载',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('$cached / $total 章已缓存',
                    style: TextStyle(
                        color: cached > 0 ? ThemeColors.successText(context) : ThemeColors.mutedText(context),
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            if (_downloading) ...[
              _buildProgressBar(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.stop, size: 18),
                      label: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (total > 0)
                    ActionChip(
                      label: const Text('缓存本章'),
                      avatar: const Icon(Icons.download, size: 16),
                      onPressed: () => _download(currentIdx, currentIdx, '缓存本章'),
                    ),
                  if (total > currentIdx + 1)
                    ActionChip(
                      label: const Text('后 5 章'),
                      avatar: const Icon(Icons.download, size: 16),
                      onPressed: () =>
                          _download(currentIdx, currentIdx + 5, '缓存后 5 章'),
                    ),
                  if (total > currentIdx + 5)
                    ActionChip(
                      label: const Text('后 10 章'),
                      avatar: const Icon(Icons.download, size: 16),
                      onPressed: () =>
                          _download(currentIdx, currentIdx + 10, '缓存后 10 章'),
                    ),
                  ActionChip(
                    label: const Text('全部缓存'),
                    avatar: const Icon(Icons.download_for_offline, size: 16),
                    onPressed: () => _download(0, total - 1, '全部缓存'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (cached > 0)
                TextButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('清除本书缓存'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final p = _progress;
    final ratio = p?.ratio ?? 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: ratio,
          minHeight: 6,
          backgroundColor: ThemeColors.surfaceLevel2(context),
        ),
        const SizedBox(height: 6),
        Text(
          '${p?.completed ?? 0} / ${p?.total ?? 0}'
          ' · 成功 ${p?.succeeded ?? 0}'
          ' · 跳过 ${p?.skipped ?? 0}'
          ' · 失败 ${p?.failed ?? 0}',
          style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12),
        ),
        if (p?.current != null && p!.current.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '正在下载：${p.current}',
              style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
