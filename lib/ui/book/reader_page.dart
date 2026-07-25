import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/domain/usecases/resolve_chapter_content.dart';
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

  double _fontSize = 18;
  static const _backgrounds = [
    _Bg(Colors.white, Colors.black87),
    _Bg(Color(0xFFF5F1E8), Colors.black87), // 护眼米黄
    _Bg(Color(0xFF1F1F1F), Colors.white70), // 夜间
  ];
  int _bgIndex = 0;
  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.args.initialIndex;
    _currentBook = widget.args.book;
    _currentChapters = widget.args.chapters;
    _load();
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
    return list
        .where((b) => b.sourceUrl != currentUrl)
        .toList();
  }

  Future<void> _goChapter(int index) async {
    if (index < 0 || index >= _currentChapters.length) return;
    _currentIndex = index;
    await _load();
  }

  void _showSwitchDialog(ResolvedContent resolved) {
    final bg = _backgrounds[_bgIndex];
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
              child: Text('暂不切换',
                  style: TextStyle(color: bg.foreground.withOpacity(0.6))),
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

  @override
  Widget build(BuildContext context) {
    final bg = _backgrounds[_bgIndex];
    final isOnSwitchedSource =
        _currentBook.sourceUrl != widget.args.book.sourceUrl;
    return Scaffold(
      backgroundColor: bg.color,
      appBar: AppBar(
        backgroundColor: bg.color,
        foregroundColor: bg.foreground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/book',
              extra: SearchResult(
                bookName: widget.args.book.name ?? '',
                author: widget.args.book.author ?? '',
                coverUrl: widget.args.book.coverUrl,
                intro: widget.args.book.intro,
                kind: widget.args.book.kind,
                wordCount: widget.args.book.wordCount,
                lastChapter: widget.args.book.lastChapter,
                sources: [
                  SearchSource(
                    sourceName: widget.args.book.sourceName,
                    sourceUrl: widget.args.book.sourceUrl,
                    bookUrl: widget.args.book.url,
                  ),
                ],
              )),
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
            icon: const Icon(Icons.tune),
            onPressed: () => setState(() => _settingsOpen = !_settingsOpen),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
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
          else
            GestureDetector(
              onTap: () => setState(() => _settingsOpen = !_settingsOpen),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _currentChapter.name,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: bg.foreground),
                  ),
                  if (_lastResolved?.isVip == true &&
                      _lastResolved?.switchedTo == null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.4), width: 1),
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
                            label: const Text('重试换源',
                                style: TextStyle(fontSize: 12)),
                            onPressed: _manualResolve,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _content?.isNotEmpty == true
                        ? _content!
                        : '（本章内容为空）',
                    style: TextStyle(
                        fontSize: _fontSize,
                        height: 1.7,
                        color: bg.foreground),
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
              ),
            ),
          if (_settingsOpen) _buildSettingsPanel(bg),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(_Bg bg) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: bg.color.withOpacity(0.97),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('字号', style: TextStyle(color: bg.foreground, fontSize: 14)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() {
                      if (_fontSize > 12) _fontSize -= 1;
                    }),
                  ),
                  Text('${_fontSize.toInt()}',
                      style: TextStyle(color: bg.foreground)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() {
                      if (_fontSize < 32) _fontSize += 1;
                    }),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _fontSize = 18;
                      _bgIndex = 0;
                    }),
                    child: const Text('重置'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('背景', style: TextStyle(color: bg.foreground, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < _backgrounds.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _bgIndex = i),
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _backgrounds[i].color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _bgIndex == i
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            width: _bgIndex == i ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bg {
  final Color color;
  final Color foreground;
  const _Bg(this.color, this.foreground);
}
