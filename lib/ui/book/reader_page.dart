import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 阅读器入参。
class ReaderArgs {
  final BookInfo book;
  final List<Chapter> chapters;
  final int initialIndex;
  const ReaderArgs({
    required this.book,
    required this.chapters,
    required this.initialIndex,
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
    _load();
  }

  Chapter get _currentChapter => widget.args.chapters[_currentIndex];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final useCase = ref.read(getChapterContentProvider);
      final content = await useCase(widget.args.book, _currentChapter);
      if (!mounted) return;
      setState(() {
        _content = content;
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

  Future<void> _goChapter(int index) async {
    if (index < 0 || index >= widget.args.chapters.length) return;
    _currentIndex = index;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgrounds[_bgIndex];
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
                  const SizedBox(height: 16),
                  Text(
                    _content?.isNotEmpty == true ? _content! : '（本章内容为空）',
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
                        onPressed: _currentIndex < widget.args.chapters.length - 1
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
