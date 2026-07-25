import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/ui/audio/audio_player_page.dart';
import 'package:book_reader/ui/book/chapter_download_sheet.dart';
import 'package:book_reader/ui/book/reader_page.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookDetailPage extends ConsumerStatefulWidget {
  final SearchResult searchResult;
  const BookDetailPage({super.key, required this.searchResult});

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  BookInfo? _info;
  List<Chapter> _chapters = const [];
  bool _loadingInfo = true;
  bool _loadingToc = false;
  bool _loadingAudio = false;
  bool _switchingSource = false;
  String? _error;

  /// 是否已在书架中。
  bool _inBookshelf = false;

  /// 当前书架记录（若存在）。
  BookshelfEntry? _entry;

  /// 当前生效的书源 URL。null 表示尚未确定（首次加载时由 _loadInfo 选定）。
  String? _activeSourceUrl;

  // ── 相关推荐 (D-2) ──────────────────────────────────────────
  /// 相关推荐结果。
  List<SearchResult> _related = const [];
  bool _loadingRelated = false;

  // ── 目录折叠 / 搜索 (D-3) ──────────────────────────────────────────
  /// 是否处于目录搜索模式。
  bool _tocSearchMode = false;

  /// 目录搜索关键字。
  String _tocQuery = '';

  /// 已折叠的卷标名集合。
  final Set<String> _collapsedVolumes = {};

  String get _id => BookshelfEntry.makeId(
      widget.searchResult.bookName, widget.searchResult.author);

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadBookshelfStatus();
    _loadRelated();
  }

  /// D-2：异步加载相关推荐（不影响主信息加载）。
  Future<void> _loadRelated() async {
    setState(() => _loadingRelated = true);
    try {
      final useCase = ref.read(getRelatedBooksProvider);
      final list = await useCase(widget.searchResult, limit: 6);
      if (!mounted) return;
      setState(() => _related = list);
    } catch (_) {
      // 静默：推荐是辅助信息
    } finally {
      if (mounted) setState(() => _loadingRelated = false);
    }
  }

  Future<void> _loadBookshelfStatus() async {
    final repo = ref.read(bookshelfRepositoryProvider);
    final entry = await repo.getById(_id);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _inBookshelf = entry != null;
    });
  }

  Future<void> _toggleBookshelf() async {
    final repo = ref.read(bookshelfRepositoryProvider);
    if (_inBookshelf) {
      await repo.delete(_id);
      if (!mounted) return;
      setState(() {
        _inBookshelf = false;
        _entry = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已移出书架')),
      );
    } else {
      final sr = widget.searchResult;
      final info = _info;
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = BookshelfEntry(
        id: _id,
        bookName: info?.name ?? sr.bookName,
        author: info?.author ?? sr.author,
        coverUrl: info?.coverUrl ?? sr.coverUrl,
        intro: info?.intro ?? sr.intro,
        kind: info?.kind ?? sr.kind,
        wordCount: info?.wordCount ?? sr.wordCount,
        lastChapter: info?.lastChapter ?? sr.lastChapter,
        sourceName: info?.sourceName ?? sr.sources.first.sourceName,
        sourceUrl: info?.sourceUrl ?? sr.sources.first.sourceUrl,
        bookUrl: info?.url ?? sr.sources.first.bookUrl,
        lastReadAt: now,
        addedAt: now,
      );
      await repo.upsert(entry);
      if (!mounted) return;
      setState(() {
        _inBookshelf = true;
        _entry = entry;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入书架')),
      );
    }
  }

  Future<void> _loadInfo({SearchSource? explicitSource}) async {
    setState(() {
      _loadingInfo = true;
      _error = null;
    });
    try {
      final useCase = ref.read(getBookInfoProvider);
      // 直接构造一个只含目标源的 SearchResult 来调用 useCase
      final sr = explicitSource == null
          ? widget.searchResult
          : SearchResult(
              bookName: widget.searchResult.bookName,
              author: widget.searchResult.author,
              coverUrl: widget.searchResult.coverUrl,
              intro: widget.searchResult.intro,
              kind: widget.searchResult.kind,
              wordCount: widget.searchResult.wordCount,
              lastChapter: widget.searchResult.lastChapter,
              sources: [explicitSource],
            );
      final info = await useCase(sr);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loadingInfo = false;
        if (info != null) _activeSourceUrl = info.sourceUrl;
      });
      if (info != null) _loadToc(info);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loadingInfo = false;
      });
    }
  }

  /// D-1：切换到指定书源，重新拉取详情 + 目录。
  Future<void> _switchSource(SearchSource src) async {
    if (_switchingSource) return;
    if (src.sourceUrl == _activeSourceUrl) return;
    setState(() {
      _switchingSource = true;
      _error = null;
      _chapters = const [];
      _collapsedVolumes.clear();
      _tocQuery = '';
      _tocSearchMode = false;
    });
    try {
      final useCase = ref.read(getBookInfoProvider);
      final sr = SearchResult(
        bookName: widget.searchResult.bookName,
        author: widget.searchResult.author,
        coverUrl: widget.searchResult.coverUrl,
        intro: widget.searchResult.intro,
        kind: widget.searchResult.kind,
        wordCount: widget.searchResult.wordCount,
        lastChapter: widget.searchResult.lastChapter,
        sources: [src],
      );
      final info = await useCase(sr);
      if (!mounted) return;
      setState(() {
        _info = info;
        _activeSourceUrl = info?.sourceUrl ?? src.sourceUrl;
      });
      if (info != null) {
        await _loadToc(info);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '切换书源失败: $e');
    } finally {
      if (mounted) setState(() => _switchingSource = false);
    }
  }

  Future<void> _loadToc(BookInfo info) async {
    setState(() => _loadingToc = true);
    try {
      final useCase = ref.read(getTocProvider);
      final chapters = await useCase(info);
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _collapsedVolumes.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '目录加载失败: $e');
    } finally {
      if (mounted) setState(() => _loadingToc = false);
    }
  }

  Future<void> _playAudio() async {
    final info = _info;
    if (info == null) return;
    setState(() => _loadingAudio = true);
    try {
      final useCase = ref.read(getAudioTocProvider);
      final audioChapters = await useCase(info);
      if (!mounted) return;
      if (audioChapters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该书源未配置有声目录规则，无法听书')),
        );
        return;
      }
      context.go('/audio',
          extra: AudioPlayerArgs(
            book: info,
            chapters: audioChapters,
            initialIndex: 0,
          ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('听书加载失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  // ── D-3：目录折叠 / 搜索 ──────────────────────────────────────────

  void _toggleVolume(String volumeName) {
    setState(() {
      if (_collapsedVolumes.contains(volumeName)) {
        _collapsedVolumes.remove(volumeName);
      } else {
        _collapsedVolumes.add(volumeName);
      }
    });
  }

  void _collapseAllVolumes() {
    setState(() {
      _collapsedVolumes
        ..clear()
        ..addAll(_chapters.where((c) => c.isVolume).map((c) => c.name));
    });
  }

  void _expandAllVolumes() {
    setState(() => _collapsedVolumes.clear());
  }

  /// 当前应展示的章节列表：考虑搜索 + 折叠。
  ///
  /// 搜索模式下：忽略折叠，直接返回所有匹配的非卷标章节（卷标本身不参与匹配）。
  /// 非搜索模式下：跳过被折叠卷标下的章节（直到下一个卷标为止）。
  List<Chapter> get _visibleChapters {
    if (_tocSearchMode && _tocQuery.isNotEmpty) {
      final q = _tocQuery.toLowerCase();
      return _chapters
          .where((c) => !c.isVolume && c.name.toLowerCase().contains(q))
          .toList();
    }
    final result = <Chapter>[];
    bool skipping = false;
    for (final c in _chapters) {
      if (c.isVolume) {
        skipping = _collapsedVolumes.contains(c.name);
        result.add(c);
        continue;
      }
      if (skipping) continue;
      result.add(c);
    }
    return result;
  }

  /// 跳转到指定章节序号（用户输入）。
  Future<void> _jumpToChapter() async {
    if (_chapters.isEmpty) return;
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('跳转到章节', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '输入章节序号 (1 - ${_chapters.length})',
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
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    if (input == null) return;
    final idx = int.tryParse(input);
    if (idx == null || idx < 1 || idx > _chapters.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入 1 - ${_chapters.length} 之间的数字')),
      );
      return;
    }
    final target = _chapters[idx - 1];
    if (target.isVolume) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该序号是卷标，不可阅读')),
      );
      return;
    }
    if (!mounted) return;
    _openReader(_chapters.indexOf(target));
  }

  void _openReader(int chapterIndex) {
    final info = _info;
    if (info == null) return;
    context.go('/reader',
        extra: ReaderArgs(
          book: info,
          chapters: _chapters,
          initialIndex: chapterIndex,
          alternatives: _buildAlternatives(),
        ));
  }

  // ── D-4：封面大图预览 ──────────────────────────────────────────

  void _showCoverPreview(String? coverUrl) {
    if (coverUrl == null) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    minScale: 0.5,
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              size: 80, color: Colors.white70),
                          SizedBox(height: 12),
                          Text('封面加载失败',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sr = widget.searchResult;
    final info = _info;
    final name = info?.name ?? sr.bookName;
    final author = info?.author ?? sr.author;
    final cover = info?.coverUrl ?? sr.coverUrl;
    final intro = info?.intro ?? sr.intro;
    final kind = info?.kind ?? sr.kind;
    final wordCount = info?.wordCount ?? sr.wordCount;
    final lastChapter = info?.lastChapter ?? sr.lastChapter;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/search'),
        ),
        title: Text(name),
      ),
      body: _loadingInfo
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 顶部信息区 + 加入书架按钮
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cover != null)
                        GestureDetector(
                          onTap: () => _showCoverPreview(cover),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              cover,
                              width: 100,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _coverPlaceholder(100, 140),
                            ),
                          ),
                        )
                      else
                        _coverPlaceholder(100, 140),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(author,
                                style: TextStyle(
                                    color: ThemeColors.mutedText(context), fontSize: 14)),
                            if (kind != null) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: kind.split(RegExp(r'[,，、\s]+'))
                                    .where((s) => s.isNotEmpty)
                                    .map((k) => Chip(
                                          label: Text(k, style: const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ))
                                    .toList(),
                              ),
                            ],
                            if (wordCount != null) ...[
                              const SizedBox(height: 6),
                              Text('$wordCount · 共 ${_chapters.length} 章',
                                  style: TextStyle(
                                      color: ThemeColors.mutedText(context), fontSize: 12)),
                            ],
                            const SizedBox(height: 10),
                            // 加入书架按钮
                            OutlinedButton.icon(
                              onPressed: _toggleBookshelf,
                              icon: Icon(
                                _inBookshelf
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 16,
                              ),
                              label: Text(_inBookshelf ? '已收藏' : '加入书架'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                minimumSize: const Size(0, 32),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // D-1: 多源对比区
                _buildSourcesSection(),
                if (intro != null) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('简介',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Text(intro, style: const TextStyle(height: 1.5, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                if (lastChapter != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: ThemeColors.mutedText(context)),
                        const SizedBox(width: 6),
                        Text('最新: $lastChapter',
                            style: TextStyle(
                                color: ThemeColors.mutedText(context), fontSize: 12)),
                      ],
                    ),
                  ),
                // D-2: 相关推荐
                _buildRelatedSection(),
                const Divider(height: 1),
                // D-3: 目录头部（含搜索 + 折叠 + 跳转）
                _buildTocHeader(),
                if (_tocSearchMode) _buildTocSearchField(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                // D-3: 目录列表（支持折叠 / 搜索过滤）
                ..._buildChapterList(),
              ],
            ),
      bottomNavigationBar: _info == null || _chapters.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                      top: BorderSide(color: ThemeColors.outline(context), width: 0.5)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '加入书架',
                      onPressed: _toggleBookshelf,
                      icon: Icon(
                        _inBookshelf
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _inBookshelf
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final info2 = _info!;
                          // 若有续读进度，从上次章节开始；否则从第一章开始
                          final start = (_entry?.lastChapterIndex ?? 0)
                              .clamp(0, _chapters.length - 1);
                          context.go('/reader',
                              extra: ReaderArgs(
                                book: info2,
                                chapters: _chapters,
                                initialIndex: start,
                                alternatives: _buildAlternatives(),
                              ));
                        },
                        icon: const Icon(Icons.menu_book),
                        label: Text(
                          _entry?.lastChapterIndex != null
                              ? '继续阅读 · ${_entry?.lastChapterName ?? ''}'
                              : '开始阅读',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── D-2: 相关推荐区 ──────────────────────────────────────────

  Widget _buildRelatedSection() {
    // 加载中：显示骨架行
    if (_loadingRelated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.recommend, size: 16),
                const SizedBox(width: 6),
                const Text('相关推荐',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => Container(
                width: 90,
                decoration: BoxDecoration(
                  color: ThemeColors.surfaceLevel1(context),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_related.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.recommend, size: 16),
              const SizedBox(width: 6),
              const Text('相关推荐',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_related.length} 本',
                  style:
                      TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _relatedBookCard(_related[i]),
          ),
        ),
      ],
    );
  }

  Widget _relatedBookCard(SearchResult r) {
    final cover = r.coverUrl;
    return InkWell(
      onTap: () => context.go('/book', extra: r),
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  cover,
                  width: 96,
                  height: 128,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder(96, 128),
                ),
              )
            else
              _coverPlaceholder(96, 128),
            const SizedBox(height: 4),
            Text(r.bookName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text(r.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: ThemeColors.mutedText(context), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── D-1: 多源对比区 ──────────────────────────────────────────

  Widget _buildSourcesSection() {
    final sources = widget.searchResult.sources;
    if (sources.length <= 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.layers, size: 16),
              const SizedBox(width: 6),
              Text('书源 (${sources.length})',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_switchingSource)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in sources)
                _sourceChip(s, isActive: s.sourceUrl == _activeSourceUrl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sourceChip(SearchSource s, {required bool isActive}) {
    return InkWell(
      onTap: _switchingSource ? null : () => _switchSource(s),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : ThemeColors.surfaceLevel1(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.sourceName,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : ThemeColors.mutedText(context),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                )),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle,
                  size: 12, color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }

  // ── D-3: 目录头部 ──────────────────────────────────────────

  Widget _buildTocHeader() {
    final hasVolumes = _chapters.any((c) => c.isVolume);
    return ListTile(
      dense: true,
      title: Text('目录 (${_chapters.length})',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Wrap(
        spacing: 0,
        children: [
          if (_loadingToc)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(
            tooltip: _tocSearchMode ? '退出搜索' : '搜索章节',
            icon: Icon(
              _tocSearchMode ? Icons.search_off : Icons.search,
              size: 20,
            ),
            onPressed: _chapters.isEmpty
                ? null
                : () => setState(() {
                      _tocSearchMode = !_tocSearchMode;
                      _tocQuery = '';
                    }),
          ),
          IconButton(
            tooltip: '跳转到章节',
            icon: Icon(Icons.input, size: 20),
            onPressed: _chapters.isEmpty ? null : _jumpToChapter,
          ),
          IconButton(
            tooltip: '离线下载',
            icon: const Icon(Icons.download_for_offline, size: 20),
            onPressed: _chapters.isEmpty || _info == null
                ? null
                : () => ChapterDownloadSheet.show(
                      context,
                      book: _info!,
                      chapters: _chapters,
                      currentIndex: 0,
                    ),
          ),
          if (hasVolumes && !_tocSearchMode)
            IconButton(
              tooltip: _collapsedVolumes.isEmpty ? '全部折叠' : '全部展开',
              icon: Icon(
                _collapsedVolumes.isEmpty
                    ? Icons.unfold_less
                    : Icons.unfold_more,
                size: 20,
              ),
              onPressed: () => _collapsedVolumes.isEmpty
                  ? _collapseAllVolumes()
                  : _expandAllVolumes(),
            ),
          if (_info != null && _chapters.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.headphones, size: 18),
              label: const Text('听书'),
              onPressed: _loadingAudio ? null : _playAudio,
            ),
        ],
      ),
    );
  }

  Widget _buildTocSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        autofocus: true,
        onChanged: (v) => setState(() => _tocQuery = v),
        controller: TextEditingController(text: _tocQuery),
        decoration: InputDecoration(
          isDense: true,
          hintText: '输入章节名关键字',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _tocQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => setState(() => _tocQuery = ''),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  List<Widget> _buildChapterList() {
    final visible = _visibleChapters;
    if (_tocSearchMode && _tocQuery.isNotEmpty) {
      if (visible.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('没有匹配「$_tocQuery」的章节',
                  style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 13)),
            ),
          ),
        ];
      }
      return [
        for (final c in visible)
          ListTile(
            dense: true,
            leading: Text('${c.index}',
                style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
            title: Text(c.name,
                style: const TextStyle(fontSize: 14)),
            trailing: c.isVip
                ? Icon(Icons.lock, size: 14, color: Colors.orange.shade400)
                : null,
            onTap: () => _openReader(_chapters.indexOf(c)),
          ),
      ];
    }
    return [
      for (final c in visible)
        ListTile(
          dense: true,
          leading: c.isVolume
              ? Icon(Icons.folder, size: 16, color: ThemeColors.mutedText(context))
              : Text('${c.index}',
                  style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
          title: Text(c.name,
              style: TextStyle(
                  fontSize: 14,
                  color: c.isVolume ? ThemeColors.mutedText(context) : null,
                  fontWeight:
                      c.isVolume ? FontWeight.bold : FontWeight.normal)),
          trailing: c.isVolume
              ? Icon(
                  _collapsedVolumes.contains(c.name)
                      ? Icons.expand_more
                      : Icons.expand_less,
                  size: 18,
                  color: ThemeColors.mutedText(context))
              : c.isVip
                  ? Icon(Icons.lock, size: 14, color: Colors.orange.shade400)
                  : null,
          enabled: !c.isVolume,
          onTap: c.isVolume
              ? () => _toggleVolume(c.name)
              : () => _openReader(_chapters.indexOf(c)),
        ),
    ];
  }

  Widget _coverPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: ThemeColors.surfaceLevel2(context),
      child: Icon(Icons.book, color: ThemeColors.mutedText(context)),
    );
  }

  /// 构造备选书源列表（去除当前书源）。
  ///
  /// 用搜索结果中的多源信息构造最小 [BookInfo]，
  /// 供 ReaderPage 在遇到 VIP 章节时尝试跨源回退。
  List<BookInfo> _buildAlternatives() {
    final currentUrl = _activeSourceUrl ?? _info?.sourceUrl ?? widget.searchResult.sources.first.sourceUrl;
    return widget.searchResult.sources
        .where((s) => s.sourceUrl != currentUrl)
        .map((s) => BookInfo(
              url: s.bookUrl,
              sourceName: s.sourceName,
              sourceUrl: s.sourceUrl,
              name: widget.searchResult.bookName,
              author: widget.searchResult.author,
            ))
        .toList();
  }
}
