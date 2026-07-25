import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/ui/audio/audio_player_page.dart';
import 'package:book_reader/ui/book/reader_page.dart';
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
  String? _error;

  /// 是否已在书架中。
  bool _inBookshelf = false;

  /// 当前书架记录（若存在）。
  BookshelfEntry? _entry;

  String get _id => BookshelfEntry.makeId(
      widget.searchResult.bookName, widget.searchResult.author);

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadBookshelfStatus();
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

  Future<void> _loadInfo() async {
    try {
      final useCase = ref.read(getBookInfoProvider);
      final info = await useCase(widget.searchResult);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loadingInfo = false;
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

  Future<void> _loadToc(BookInfo info) async {
    setState(() => _loadingToc = true);
    try {
      final useCase = ref.read(getTocProvider);
      final chapters = await useCase(info);
      if (!mounted) return;
      setState(() => _chapters = chapters);
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            cover,
                            width: 100,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder(100, 140),
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
                                    color: Colors.grey.shade700, fontSize: 14)),
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
                                      color: Colors.grey.shade600, fontSize: 12)),
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
                        Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text('最新: $lastChapter',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text('目录 (${_chapters.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loadingToc)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      if (_info != null && _chapters.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.headphones, size: 18),
                          label: const Text('听书'),
                          onPressed: _loadingAudio ? null : _playAudio,
                        ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                for (final c in _chapters)
                  ListTile(
                    dense: true,
                    leading: Text('${c.index}',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12)),
                    title: Text(c.name,
                        style: TextStyle(
                            fontSize: 14,
                            color: c.isVolume ? Colors.grey.shade500 : null,
                            fontWeight:
                                c.isVolume ? FontWeight.bold : FontWeight.normal)),
                    trailing: c.isVip
                        ? Icon(Icons.lock, size: 14, color: Colors.orange.shade400)
                        : null,
                    enabled: !c.isVolume,
                    onTap: c.isVolume
                        ? null
                        : () => context.go('/reader',
                            extra: ReaderArgs(
                              book: info!,
                              chapters: _chapters,
                              initialIndex: _chapters.indexOf(c),
                              alternatives: _buildAlternatives(),
                            )),
                  ),
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
                      top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
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

  Widget _coverPlaceholder(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade200,
      child: const Icon(Icons.book, color: Colors.grey),
    );
  }

  /// 构造备选书源列表（去除当前书源）。
  ///
  /// 用搜索结果中的多源信息构造最小 [BookInfo]，
  /// 供 ReaderPage 在遇到 VIP 章节时尝试跨源回退。
  List<BookInfo> _buildAlternatives() {
    final currentUrl = _info?.sourceUrl ?? widget.searchResult.sources.first.sourceUrl;
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
