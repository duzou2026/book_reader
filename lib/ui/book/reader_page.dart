import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/domain/usecases/resolve_chapter_content.dart';
import 'package:book_reader/services/preferences/reading_prefs_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 阅读器入参。
class ReaderArgs {
  final BookInfo book;
  final List<Chapter> chapters;
  final int initialIndex;

  /// 备选书源（来自搜索结果的多源聚合）。
  ///
  /// 当原源章节为 VIP 时，会按此列表顺序尝试跨源回退。
  /// 元素为各源的最小 [BookInfo]（至少含 url/sourceUrl/sourceName）。
  final List<BookInfo> alternatives;

  const ReaderArgs({
    required this.book,
    required this.chapters,
    required this.initialIndex,
    this.alternatives = const [],
  });
}

class ReaderPage extends ConsumerStatefulWidget {
  final ReaderArgs args;
  const ReaderPage({super.key, required this.args});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  late int _currentIndex;
  String? _content;
  bool _loading = true;
  String? _error;

  /// 当前生效的书源（可能在 VIP 切换后被替换）。
  late BookInfo _currentBook;

  /// 当前生效的章节列表（可能被替换为切换后源的目录）。
  late List<Chapter> _currentChapters;

  /// 最近一次解析结果（用于判断是否需要弹切换提示）。
  ResolvedContent? _lastResolved;

  /// 标记本次切换提示是否已被用户处理（避免重复弹窗）。
  bool _switchPromptedForCurrent = false;

  /// 滚动控制器（用于恢复阅读位置）。
  final _scrollController = ScrollController();

  /// 翻页控制器（PageView 模式下使用）。
  late final PageController _pageController;

  /// 阅读时长（秒）。
  int _readingSeconds = 0;

  /// 阅读计时器。
  // ignore: unused_field
  // 这里通过 initState 启动 Timer，dispose 时取消。
  // ignore: close_sinks
  // _scrollController 在 dispose 中释放。

  static const _backgrounds = <_Bg>[
    _Bg('白', Colors.white, Colors.black87),
    _Bg('米黄', Color(0xFFF5F1E8), Colors.black87),
    _Bg('夜间', Color(0xFF1F1F1F), Colors.white70),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    _currentBook = widget.args.book;
    _currentChapters = widget.args.chapters;
    _pageController = PageController(initialPage: _currentIndex);
    _restoreProgress();
    _load();
    _startReadingTimer();
  }

  String get _id =>
      BookshelfEntry.makeId(_currentBook.name ?? '', _currentBook.author ?? '');

  void _startReadingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _readingSeconds++);
      _startReadingTimer();
    });
  }

  /// 恢复持久化的阅读位置（如果有）。
  Future<void> _restoreProgress() async {
    final progress =
        await ref.read(readingProgressRepositoryProvider).get(_id);
    if (progress == null || !mounted) return;
    if (progress.chapterIndex < _currentChapters.length) {
      _currentIndex = progress.chapterIndex;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    }
  }

  /// 持久化当前进度。
  Future<void> _persistProgress() async {
    final chapter = _currentChapter;
    await ref.read(readingProgressRepositoryProvider).updateChapter(
          id: _id,
          chapterIndex: _currentIndex,
          switchedSourceUrl: _currentBook.sourceUrl,
        );
    await ref
        .read(bookshelfRepositoryProvider)
        .updateReadingProgress(
          id: _id,
          chapterIndex: _currentIndex,
          chapterName: chapter.name,
        );
  }

  Chapter get _currentChapter => _currentChapters[_currentIndex];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _switchPromptedForCurrent = false;
    });
    try {
      final useCase = ref.read(resolveChapterContentProvider);
      final resolved = await useCase(
        book: _currentBook,
        chapter: _currentChapter,
        alternatives: _buildAlternatives(),
      );
      if (!mounted) return;
      setState(() {
        _lastResolved = resolved;
        _content = resolved.content;
        _loading = false;
      });
      // 滚到顶部
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      // 持久化进度
      _persistProgress();
      // 若跨源成功且尚未切换过 → 弹窗询问
      if (resolved.switchedTo != null && !_switchPromptedForCurrent) {
        _switchPromptedForCurrent = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSwitchDialog(resolved);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 构造跨源备选列表：去除当前生效源。
  List<BookInfo> _buildAlternatives() {
    final currentUrl = _currentBook.sourceUrl;
    final list = <BookInfo>[
      // 优先用 args 里携带的备源
      ...widget.args.alternatives,
      // 也带上原书源（如果当前已经是切换后的源）
      if (_currentBook.sourceUrl != widget.args.book.sourceUrl)
        widget.args.book,
    ];
    return list.where((b) => b.sourceUrl != currentUrl).toList();
  }

  Future<void> _goChapter(int index) async {
    if (index < 0 || index >= _currentChapters.length) return;
    final prefs = ref.read(readingPrefsProvider);
    if (prefs.pageMode == PageMode.scroll) {
      _currentIndex = index;
      await _load();
    } else {
      // PageView 模式：通过 controller 跳页，onPageChanged 会触发 _load
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  /// PageView 翻页回调：用户左右滑动后加载新章节。
  Future<void> _onPageChanged(int page) async {
    if (page == _currentIndex) return;
    _currentIndex = page;
    await _load();
  }

  void _showSwitchDialog(ResolvedContent resolved) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text('发现免费源', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(
            '本章在「${_currentBook.sourceName}」为 VIP / 付费章节。\n\n'
            '已为您在「${resolved.switchedTo!.sourceName}」找到可读版本，'
            '是否切换到该源继续阅读？\n\n'
            '切换后，后续章节也将默认使用该源。',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('暂不切换'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('切换并阅读'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _applySwitch(resolved);
              },
            ),
          ],
        );
      },
    );
  }

  /// 应用源切换：更新当前书源 + 目录 + 章节索引。
  void _applySwitch(ResolvedContent resolved) {
    final newSource = resolved.switchedTo!;
    final newToc = resolved.sourceToc ?? const <Chapter>[];
    final matchedIndex = newToc.indexOf(resolved.switchedChapter!);

    setState(() {
      _currentBook = newSource;
      _currentChapters = newToc;
      _currentIndex = matchedIndex >= 0 ? matchedIndex : 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换到「${newSource.sourceName}」'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 手动触发跨源搜索（用户点击"换源"按钮时）。
  Future<void> _manualResolve() async {
    setState(() => _loading = true);
    try {
      final resolver = ref.read(crossSourceContentResolverProvider);
      final resolved = await resolver.resolve(
        chapter: _currentChapter,
        alternatives: _buildAlternatives(),
      );
      if (!mounted) return;
      if (resolved == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到其他可用源')),
        );
        return;
      }
      setState(() {
        _lastResolved = ResolvedContent(
          content: resolved.content,
          switchedTo: resolved.sourceInfo,
          switchedChapter: resolved.chapter,
          sourceToc: resolved.sourceToc,
          isVip: true,
        );
        _content = resolved.content;
        _loading = false;
      });
      _showSwitchDialog(_lastResolved!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _formatReadingTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s 秒';
    return '$m 分 $s 秒';
  }

  /// 跟随系统夜间模式：若开启且系统为深色，自动切到夜间背景。
  _Bg _resolveBackground(ReadingPrefs prefs, Brightness platformBrightness) {
    final idx = (prefs.followSystemDark && platformBrightness == Brightness.dark)
        ? 2
        : prefs.backgroundIndex;
    return _backgrounds[idx.clamp(0, _backgrounds.length - 1)];
  }

  /// 点击区域翻页：左 1/3 上一章，右 1/3 下一章，中间 1/3 呼出设置。
  /// 仅在 PageView 模式下生效；scroll 模式保持滚动交互。
  void _onTapRegion(TapUpDetails details, BoxConstraints constraints) {
    final prefs = ref.read(readingPrefsProvider);
    if (prefs.pageMode == PageMode.scroll) {
      _openSettingsSheet();
      return;
    }
    final dx = details.localPosition.dx;
    final w = constraints.maxWidth;
    if (dx < w / 3) {
      if (_currentIndex > 0) _goChapter(_currentIndex - 1);
    } else if (dx > w * 2 / 3) {
      if (_currentIndex < _currentChapters.length - 1) {
        _goChapter(_currentIndex + 1);
      }
    } else {
      _openSettingsSheet();
    }
  }

  @override
  void dispose() {
    _persistProgress();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readingPrefsProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final bg = _resolveBackground(prefs, platformBrightness);
    final isOnSwitchedSource =
        _currentBook.sourceUrl != widget.args.book.sourceUrl;
    final progressPercent = _currentChapters.isEmpty
        ? 0.0
        : (_currentIndex + 1) / _currentChapters.length;
    return Scaffold(
      backgroundColor: bg.color,
      appBar: AppBar(
        backgroundColor: bg.color,
        foregroundColor: bg.foreground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _exit(),
        ),
        title: Text(_currentChapter.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
        actions: [
          if (isOnSwitchedSource)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Chip(
                label: Text(_currentBook.sourceName,
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.teal.withOpacity(0.15),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '换源',
            onPressed: _loading ? null : _manualResolve,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '目录',
            onPressed: () => _openChapterDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '设置',
            onPressed: () => _openSettingsSheet(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('加载失败：$_error',
                          style: TextStyle(color: bg.foreground)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _onTapRegion(d, constraints),
                      child: prefs.pageMode == PageMode.scroll
                          ? _buildScrollBody(prefs, bg)
                          : _buildPagedBody(prefs, bg),
                    );
                  },
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: bg.color,
                  border: Border(
                    top: BorderSide(
                        color: bg.foreground.withOpacity(0.08), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_currentIndex + 1}/${_currentChapters.length}',
                      style: TextStyle(
                          fontSize: 11, color: bg.foreground.withOpacity(0.6)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 3,
                          backgroundColor: bg.foreground.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                            bg.foreground.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '已读 ${_formatReadingTime(_readingSeconds)}',
                      style: TextStyle(
                          fontSize: 11, color: bg.foreground.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// 滚动模式正文：保留原 ListView + 上下章按钮。
  Widget _buildScrollBody(ReadingPrefs prefs, _Bg bg) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _currentChapter.name,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: bg.foreground),
        ),
        const SizedBox(height: 4),
        Text(
          '${_currentIndex + 1} / ${_currentChapters.length}',
          style: TextStyle(
            fontSize: 11,
            color: bg.foreground.withOpacity(0.5),
          ),
        ),
        if (_lastResolved?.isVip == true &&
            _lastResolved?.switchedTo == null) ...[
          const SizedBox(height: 8),
          _buildVipBlockedBanner(bg),
        ],
        const SizedBox(height: 16),
        SelectionArea(
          child: Text(
            _content?.isNotEmpty == true ? _content! : '（本章内容为空）',
            style: TextStyle(
                fontSize: prefs.fontSize,
                height: prefs.lineHeight,
                color: bg.foreground),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: _currentIndex > 0
                  ? () => _goChapter(_currentIndex - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('上一章'),
            ),
            TextButton.icon(
              onPressed: _currentIndex < _currentChapters.length - 1
                  ? () => _goChapter(_currentIndex + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('下一章'),
            ),
          ],
        ),
      ],
    );
  }

  /// 左右翻页模式正文：PageView，每页一章。
  Widget _buildPagedBody(ReadingPrefs prefs, _Bg bg) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _currentChapters.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final isCurrent = index == _currentIndex;
        // 当前页用已加载内容；其他页用占位（翻到时再加载）
        final content = isCurrent
            ? (_content?.isNotEmpty == true ? _content! : '（本章内容为空）')
            : _currentChapters[index].name;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentChapters[index].name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: bg.foreground),
              ),
              const SizedBox(height: 4),
              Text(
                '${index + 1} / ${_currentChapters.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: bg.foreground.withOpacity(0.5),
                ),
              ),
              if (isCurrent &&
                  _lastResolved?.isVip == true &&
                  _lastResolved?.switchedTo == null) ...[
                const SizedBox(height: 8),
                _buildVipBlockedBanner(bg),
              ],
              const SizedBox(height: 16),
              SelectionArea(
                child: Text(
                  content,
                  style: TextStyle(
                      fontSize: prefs.fontSize,
                      height: prefs.lineHeight,
                      color: bg.foreground),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVipBlockedBanner(_Bg bg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '本章为 VIP 章节，且未找到其他免费源',
              style: TextStyle(
                fontSize: 12,
                color: bg.foreground.withOpacity(0.8),
              ),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('重试换源', style: TextStyle(fontSize: 12)),
            onPressed: _manualResolve,
          ),
        ],
      ),
    );
  }

  /// 退出阅读：返回到详情页。
  void _exit() {
    context.go('/book',
        extra: SearchResult(
          bookName: _currentBook.name ?? '',
          author: _currentBook.author ?? '',
          coverUrl: _currentBook.coverUrl,
          intro: _currentBook.intro,
          kind: _currentBook.kind,
          wordCount: _currentBook.wordCount,
          lastChapter: _currentBook.lastChapter,
          sources: [
            SearchSource(
              sourceName: _currentBook.sourceName,
              sourceUrl: _currentBook.sourceUrl,
              bookUrl: _currentBook.url,
            ),
          ],
        ));
  }

  /// 章节抽屉。
  void _openChapterDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _ChapterDrawer(
        chapters: _currentChapters,
        currentIndex: _currentIndex,
        sourceName: _currentBook.sourceName,
        onSelected: (i) {
          Navigator.of(ctx).pop();
          _goChapter(i);
        },
      ),
    );
  }

  /// 设置面板（用 BottomSheet 替代原 Stack 覆盖层）。
  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => const _SettingsSheet(),
    );
  }
}

/// 章节抽屉：搜索 + 列表 + 跳转。
class _ChapterDrawer extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final String sourceName;
  final ValueChanged<int> onSelected;

  const _ChapterDrawer({
    required this.chapters,
    required this.currentIndex,
    required this.sourceName,
    required this.onSelected,
  });

  @override
  State<_ChapterDrawer> createState() => _ChapterDrawerState();
}

class _ChapterDrawerState extends State<_ChapterDrawer> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kw = _keyword.toLowerCase();
    final filtered = kw.isEmpty
        ? widget.chapters
        : widget.chapters
            .where((c) => c.name.toLowerCase().contains(kw))
            .toList();
    final height = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text('目录 (${widget.chapters.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.sourceName,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _keyword = v.trim()),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索章节名',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _keyword = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final c = filtered[i];
                final originalIndex = widget.chapters.indexOf(c);
                final isCurrent = originalIndex == widget.currentIndex;
                return ListTile(
                  dense: true,
                  selected: isCurrent,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  leading: Text('${c.index}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      )),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.isVolume ? Colors.grey.shade500 : null,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : (c.isVolume
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                  trailing: c.isVip
                      ? const Icon(Icons.lock,
                          size: 14, color: Colors.orange)
                      : (isCurrent
                          ? Icon(Icons.play_arrow,
                              size: 16,
                              color:
                                  Theme.of(context).colorScheme.primary)
                          : null),
                  enabled: !c.isVolume,
                  onTap: c.isVolume
                      ? null
                      : () => widget.onSelected(originalIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置面板（全局偏好，所有书共享）。
class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readingPrefsProvider);
    final notifier = ref.read(readingPrefsProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, size: 20),
                SizedBox(width: 8),
                Text('阅读设置',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 24),
            // 字号
            Row(
              children: [
                const SizedBox(width: 72, child: Text('字号')),
                Expanded(
                  child: Slider(
                    value: prefs.fontSize,
                    min: 12,
                    max: 32,
                    divisions: 20,
                    label: prefs.fontSize.toStringAsFixed(0),
                    onChanged: notifier.setFontSize,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${prefs.fontSize.toStringAsFixed(0)}',
                      textAlign: TextAlign.right),
                ),
              ],
            ),
            // 行距
            Row(
              children: [
                const SizedBox(width: 72, child: Text('行距')),
                Expanded(
                  child: Slider(
                    value: prefs.lineHeight,
                    min: 1.2,
                    max: 2.4,
                    divisions: 12,
                    label: prefs.lineHeight.toStringAsFixed(1),
                    onChanged: notifier.setLineHeight,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text('${prefs.lineHeight.toStringAsFixed(1)}',
                      textAlign: TextAlign.right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('背景', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _ReaderPage_backgrounds_for_sheet.length; i++)
                  GestureDetector(
                    onTap: () => notifier.setBackgroundIndex(i),
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _ReaderPage_backgrounds_for_sheet[i].color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: prefs.backgroundIndex == i
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                          width: prefs.backgroundIndex == i ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _ReaderPage_backgrounds_for_sheet[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            color: _ReaderPage_backgrounds_for_sheet[i]
                                .foreground
                                .withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 翻页方式
            const Text('翻页方式', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: PageMode.values.map((m) {
                final selected = prefs.pageMode == m;
                return ChoiceChip(
                  label: Text(_pageModeLabel(m)),
                  selected: selected,
                  onSelected: (_) => notifier.setPageMode(m),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 跟随系统夜间模式
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('跟随系统夜间模式'),
              subtitle: const Text('开启后夜间自动切换深色背景',
                  style: TextStyle(fontSize: 12)),
              value: prefs.followSystemDark,
              onChanged: notifier.setFollowSystemDark,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _pageModeLabel(PageMode m) {
    switch (m) {
      case PageMode.scroll:
        return '滚动';
      case PageMode.horizontal:
        return '左右翻页';
      case PageMode.simulation:
        return '仿真翻页';
    }
  }
}

// 顶部共享的背景列表（避免 ConsumerWidget 中跨文件引用私有 _Bg）。
const _ReaderPage_backgrounds_for_sheet = <_Bg>[
  _Bg('白', Colors.white, Colors.black87),
  _Bg('米黄', Color(0xFFF5F1E8), Colors.black87),
  _Bg('夜间', Color(0xFF1F1F1F), Colors.white70),
];

class _Bg {
  final String label;
  final Color color;
  final Color foreground;
  const _Bg(this.label, this.color, this.foreground);
}
