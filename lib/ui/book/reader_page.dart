import 'dart:async';

import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookmarks_repository.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/notes_repository.dart';
import 'package:book_reader/data/reading_history_repository.dart';
import 'package:book_reader/domain/usecases/resolve_chapter_content.dart';
import 'package:book_reader/services/preferences/reading_prefs_repository.dart';
import 'package:book_reader/services/text/chinese_converter.dart';
import 'package:book_reader/services/tts/tts_service.dart';
import 'package:book_reader/services/tts/edge_tts_service.dart';
import 'package:book_reader/ui/book/chapter_download_sheet.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
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

  /// 进入阅读器后是否自动启动 TTS 朗读。
  ///
  /// 用于「听书」入口对文本源走 TTS 而非音频播放器的场景。
  final bool autoStartTts;

  const ReaderArgs({
    required this.book,
    required this.chapters,
    required this.initialIndex,
    this.alternatives = const [],
    this.autoStartTts = false,
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

  /// 标记 autoStartTts 是否已触发过（只在首次加载完成后触发一次）。
  bool _autoTtsTriggered = false;

  /// 滚动控制器（用于恢复阅读位置）。
  final _scrollController = ScrollController();

  /// 翻页控制器（PageView 模式下使用）。
  late final PageController _pageController;

  /// 阅读时长（秒）。
  int _readingSeconds = 0;

  /// 阅读计时器。
  Timer? _readingTimer;

  /// 自动阅读计时器（按速度滚动或翻页）。
  Timer? _autoReadTimer;

  /// TTS 状态。
  TtsPlayState _ttsState = TtsPlayState.stopped;

  /// TTS 朗读进度（0.0-1.0）。
  double _ttsProgress = 0.0;

  /// 朗读时是否自动跟随滚动文本。用户手动滚动后置 false，停止跟随。
  bool _autoFollowTts = true;

  /// 当前章节的所有笔记（用于划线高亮）。
  List<Note> _chapterNotes = const [];

  /// 当前章节是否已加入书签。
  bool _isBookmarked = false;

  /// 章节字数（用于统计）。
  int _chapterWordCount = 0;

  /// 最近一次选中的文本（用于添加笔记）。
  String _lastSelection = '';

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
    _setupTtsCallbacks();
  }

  String get _id =>
      BookshelfEntry.makeId(_currentBook.name ?? '', _currentBook.author ?? '');

  void _startReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _readingTimer?.cancel();
        return;
      }
      setState(() => _readingSeconds++);
    });
  }

  /// 绑定 TTS 服务回调：状态/进度/完成/错误。
  void _setupTtsCallbacks() {
    final tts = ref.read(ttsServiceProvider);
    tts.onStateChanged = (s) {
      if (!mounted) return;
      setState(() => _ttsState = s);
    };
    tts.onProgress = (p) {
      if (!mounted) return;
      setState(() => _ttsProgress = p);
      // 朗读时文本自动跟随：按音频进度比例滚动到对应位置
      _autoFollowScroll(p);
    };
    tts.onComplete = () {
      if (!mounted) return;
      setState(() => _ttsProgress = 0.0);
      // 自动朗读下一章
      if (_currentIndex < _currentChapters.length - 1) {
        _goChapter(_currentIndex + 1);
      }
    };
    tts.onError = (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e), duration: const Duration(seconds: 2)),
      );
    };
  }

  /// 朗读进度驱动的自动滚动：按音频进度比例平滑滚动文本。
  ///
  /// 音频进度（position/duration）与文本长度大致成正比（朗读速度恒定），
  /// 用比例近似定位。用户手动滚动后 [_autoFollowTts] 置 false，停止跟随，
  /// 避免强制拉回干扰用户翻看。
  void _autoFollowScroll(double progress) {
    if (!_autoFollowTts) return;
    final sc = _scrollController;
    if (!sc.hasClients) return;
    final max = sc.position.maxScrollExtent;
    if (max <= 0) return;
    final target = (progress * max).clamp(0.0, max);
    // 用 jumpTo 避免动画堆积（onProgress 高频回调），平滑跟随
    if ((sc.offset - target).abs() > 8) {
      sc.jumpTo(target);
    }
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
      // 同步加载本章笔记和书签状态
      final notesRepo = ref.read(noteRepositoryProvider);
      final bookmarkRepo = ref.read(bookmarkRepositoryProvider);
      final allNotes = await notesRepo.getByBook(_id);
      final chapterNotes =
          allNotes.where((n) => n.chapterIndex == _currentIndex).toList();
      final bmId = '$_id|$_currentIndex';
      final bookmarked = await bookmarkRepo.exists(bmId);
      if (!mounted) return;
      setState(() {
        _lastResolved = resolved;
        _content = resolved.content;
        _chapterNotes = chapterNotes;
        _isBookmarked = bookmarked;
        _chapterWordCount = _estimateWordCount(resolved.content);
        _loading = false;
      });
      // 切换章节时停止 TTS
      _stopTts();
      // 首次加载且 autoStartTts=true 时，自动启动朗读
      if (widget.args.autoStartTts && !_autoTtsTriggered) {
        _autoTtsTriggered = true;
        if (_content != null && _content!.trim().isNotEmpty) {
          final tts = ref.read(ttsServiceProvider);
          final prefs = ref.read(readingPrefsProvider);
          if (tts is EdgeTtsService) tts.voice = prefs.ttsVoice;
          tts.speak(
            _content!,
            rate: prefs.ttsRate,
            pitch: prefs.ttsPitch,
          );
        }
      }
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

  /// 估算字数：去除空白字符后的字符数。
  int _estimateWordCount(String? text) {
    if (text == null || text.isEmpty) return 0;
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');
    return cleaned.length;
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
    // 切章时停止 TTS 与自动阅读
    _stopTts();
    _stopAutoRead();
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

  /// 构造顶部「图标+文字」双标按钮。
  ///
  /// 纯图标在移动端 tooltip 基本无效，用户不知道每个图标代表什么。
  /// 改为图标下方带一行小字（10sp），直接看懂功能，参考番茄/起点/Legado 做法。
  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onPressed,
  }) {
    final fg = color ?? Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
    _persistReadingStats();
    _persistReadingHistory();
    _stopTts();
    _stopAutoRead();
    _readingTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// 持久化今日阅读统计：累加时长和字数。
  Future<void> _persistReadingStats() async {
    if (_readingSeconds <= 0) return;
    try {
      await ref
          .read(readingStatsRepositoryProvider)
          .addToday(
            durationSeconds: _readingSeconds,
            wordCount: _chapterWordCount,
          );
    } catch (_) {
      // 静默失败：统计不应影响阅读流程
    }
  }

  /// 写入一条阅读历史记录（独立于书架）。
  Future<void> _persistReadingHistory() async {
    try {
      final chapter = _currentChapter;
      final entry = ReadingHistoryEntry(
        id: '${DateTime.now().millisecondsSinceEpoch}|$_id',
        bookId: _id,
        bookName: _currentBook.name ?? '',
        author: _currentBook.author ?? '',
        coverUrl: _currentBook.coverUrl,
        sourceName: _currentBook.sourceName,
        sourceUrl: _currentBook.sourceUrl,
        bookUrl: _currentBook.url,
        chapterIndex: _currentIndex,
        chapterName: chapter.name,
        durationSeconds: _readingSeconds,
        readAt: DateTime.now().millisecondsSinceEpoch,
      );
      await ref.read(readingHistoryRepositoryProvider).add(entry);
    } catch (_) {
      // 静默失败：历史不应影响阅读流程
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // TTS 朗读
  // ───────────────────────────────────────────────────────────────────

  /// 同步发音人到当前偏好（EdgeTtsService 支持运行时切换 voice）。
  void _syncTtsVoice() {
    final tts = ref.read(ttsServiceProvider);
    final prefs = ref.read(readingPrefsProvider);
    if (tts is EdgeTtsService && tts.voice != prefs.ttsVoice) {
      tts.voice = prefs.ttsVoice;
    }
  }

  /// 切换 TTS：停止→朗读 / 朗读→暂停 / 暂停→恢复。
  Future<void> _toggleTts() async {
    final tts = ref.read(ttsServiceProvider);
    final prefs = ref.read(readingPrefsProvider);
    switch (_ttsState) {
      case TtsPlayState.speaking:
        tts.pause();
        break;
      case TtsPlayState.paused:
        tts.resume();
        break;
      case TtsPlayState.stopped:
        final text = _content ?? '';
        if (text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('本章无内容可朗读')),
          );
          return;
        }
        // 自动阅读暂停，避免冲突
        _stopAutoRead();
        _syncTtsVoice();
        tts.speak(
          text,
          rate: prefs.ttsRate,
          pitch: prefs.ttsPitch,
        );
        break;
    }
  }

  void _stopTts() {
    final tts = ref.read(ttsServiceProvider);
    if (tts.state != TtsPlayState.stopped) {
      tts.stop();
    }
    if (mounted) setState(() => _ttsProgress = 0.0);
  }

  // ───────────────────────────────────────────────────────────────────
  // 自动阅读
  // ───────────────────────────────────────────────────────────────────

  /// 切换自动阅读：开启时按速度滚动/翻页，关闭时停止。
  void _toggleAutoRead() {
    final prefs = ref.read(readingPrefsProvider);
    if (_autoReadTimer != null) {
      _stopAutoRead();
      return;
    }
    // 开启自动阅读时停止 TTS
    _stopTts();
    final speed = prefs.autoReadSpeed <= 0 ? 30 : prefs.autoReadSpeed;
    // 若当前未设置自动阅读速度，先写入一个默认值
    if (prefs.autoReadSpeed <= 0) {
      ref.read(readingPrefsProvider.notifier).setAutoReadSpeed(speed);
    }
    _startAutoRead(speed);
  }

  void _startAutoRead(int linesPerMinute) {
    _autoReadTimer?.cancel();
    final prefs = ref.read(readingPrefsProvider);
    if (prefs.pageMode == PageMode.scroll) {
      // 滚动模式：每 100ms 向下滚一行
      final pixelsPerTick = (linesPerMinute *
              prefs.fontSize *
              prefs.lineHeight /
              600)
          .clamp(0.5, 20.0);
      _autoReadTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted || !_scrollController.hasClients) {
          _stopAutoRead();
          return;
        }
        final sc = _scrollController;
        final max = sc.position.maxScrollExtent;
        final next = sc.offset + pixelsPerTick;
        if (next >= max) {
          // 到底，自动翻到下一章
          if (_currentIndex < _currentChapters.length - 1) {
            _goChapter(_currentIndex + 1);
          } else {
            _stopAutoRead();
          }
        } else {
          sc.jumpTo(next);
        }
      });
    } else {
      // 翻页模式：按速度计算翻页间隔
      final secondsPerPage = (60 / linesPerMinute).clamp(2.0, 60.0);
      _autoReadTimer = Timer.periodic(
        Duration(milliseconds: (secondsPerPage * 1000).round()),
        (_) {
          if (!mounted) {
            _stopAutoRead();
            return;
          }
          if (_currentIndex < _currentChapters.length - 1) {
            _goChapter(_currentIndex + 1);
          } else {
            _stopAutoRead();
          }
        },
      );
    }
  }

  void _stopAutoRead() {
    _autoReadTimer?.cancel();
    _autoReadTimer = null;
    if (mounted) setState(() {});
  }

  // ───────────────────────────────────────────────────────────────────
  // 书签与笔记
  // ───────────────────────────────────────────────────────────────────

  /// 切换当前章节书签。
  Future<void> _toggleBookmark() async {
    final repo = ref.read(bookmarkRepositoryProvider);
    final bmId = '$_id|$_currentIndex';
    final bookmark = Bookmark(
      id: bmId,
      bookId: _id,
      chapterIndex: _currentIndex,
      chapterName: _currentChapter.name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await repo.toggle(bookmark);
    if (!mounted) return;
    setState(() => _isBookmarked = !_isBookmarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isBookmarked ? '已加入书签' : '已移除书签'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 添加划线笔记。
  Future<void> _addNoteFromSelection(String selectedText) async {
    final trimmed = selectedText.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择文本')),
      );
      return;
    }
    final thought = await showDialog<String>(
      context: context,
      builder: (ctx) => _AddNoteDialog(selectedText: trimmed),
    );
    if (thought == null) return;
    final note = Note(
      id: '$_id|$_currentIndex|${DateTime.now().millisecondsSinceEpoch}',
      bookId: _id,
      chapterIndex: _currentIndex,
      chapterName: _currentChapter.name,
      text: trimmed,
      thought: thought.isEmpty ? null : thought,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(noteRepositoryProvider).add(note);
    if (!mounted) return;
    setState(() => _chapterNotes = [..._chapterNotes, note]);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('笔记已保存'), duration: Duration(seconds: 1)),
    );
  }

  /// 删除笔记。
  Future<void> _deleteNote(Note note) async {
    await ref.read(noteRepositoryProvider).delete(note.id);
    if (!mounted) return;
    setState(() {
      _chapterNotes = _chapterNotes.where((n) => n.id != note.id).toList();
    });
  }

  /// 打开笔记/书签抽屉。
  Future<void> _openNotesDrawer() async {
    final notes = await ref.read(noteRepositoryProvider).getByBook(_id);
    final bookmarks = await ref.read(bookmarkRepositoryProvider).getByBook(_id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _NotesBookmarksSheet(
        notes: notes,
        bookmarks: bookmarks,
        currentChapterIndex: _currentIndex,
        onJumpBookmark: (i) {
          Navigator.of(ctx).pop();
          _goChapter(i);
        },
        onDeleteNote: (n) async {
          await _deleteNote(n);
        },
      ),
    );
  }

  /// 把内容文本转换为带笔记高亮的 InlineSpan。
  ///
  /// 简单实现：按笔记文本出现位置切分，匹配片段以高亮颜色渲染。
  InlineSpan _buildAnnotatedContent(String text, _Bg bg, ReadingPrefs prefs) {
    if (_chapterNotes.isEmpty) {
      return TextSpan(
        text: text,
        style: _contentStyle(bg, prefs),
      );
    }
    // 找出所有笔记文本在正文中的位置（不去重）
    final ranges = <_TextRange>[];
    for (final note in _chapterNotes) {
      var start = text.indexOf(note.text);
      while (start >= 0) {
        ranges.add(_TextRange(start, start + note.text.length, note));
        start = text.indexOf(note.text, start + 1);
      }
    }
    if (ranges.isEmpty) {
      return TextSpan(
        text: text,
        style: _contentStyle(bg, prefs),
      );
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    // 合并重叠区间（保留最早笔记引用）
    final merged = <_TextRange>[];
    for (final r in ranges) {
      if (merged.isEmpty || r.start > merged.last.end) {
        merged.add(r);
      } else {
        merged[merged.length - 1] = _TextRange(
          merged.last.start,
          r.end > merged.last.end ? r.end : merged.last.end,
          merged.last.note,
        );
      }
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final r in merged) {
      if (r.start > cursor) {
        children.add(TextSpan(
          text: text.substring(cursor, r.start),
          style: _contentStyle(bg, prefs),
        ));
      }
      children.add(TextSpan(
        text: text.substring(r.start, r.end),
        style: _contentStyle(bg, prefs).copyWith(
          backgroundColor: Colors.amber.withOpacity(0.35),
        ),
        recognizer: null,
        mouseCursor: SystemMouseCursors.click,
        onEnter: (_) {},
      ));
      cursor = r.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(
        text: text.substring(cursor),
        style: _contentStyle(bg, prefs),
      ));
    }
    return TextSpan(
      style: _contentStyle(bg, prefs),
      children: children,
    );
  }

  TextStyle _contentStyle(_Bg bg, ReadingPrefs prefs) {
    return TextStyle(
      fontSize: prefs.fontSize,
      height: prefs.lineHeight,
      color: bg.foreground,
      fontFamily: _fontFamilyFor(prefs.fontFamilyIndex),
    );
  }

  /// 字体索引 → font family。
  static String? _fontFamilyFor(int index) {
    switch (index) {
      case 1:
        return 'serif';
      case 2:
        return 'sans-serif';
      case 3:
        return 'monospace';
      default:
        return null;
    }
  }

  /// 应用简繁转换到展示文本。
  String _displayText(String raw, ReadingPrefs prefs) {
    return prefs.traditionalChinese
        ? ChineseConverter.toTraditional(raw)
        : raw;
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
    final isAutoReading = _autoReadTimer != null;
    final ttsIcon = _ttsState == TtsPlayState.speaking
        ? Icons.pause_circle_filled
        : _ttsState == TtsPlayState.paused
            ? Icons.play_circle_filled
            : Icons.record_voice_over;
    return Scaffold(
      backgroundColor: bg.color,
      appBar: AppBar(
        backgroundColor: bg.color,
        foregroundColor: bg.foreground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => _exit(),
        ),
        title: Text(_currentChapter.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
        // 顶部 actions 改为可横向滚动的「图标+文字」双标按钮组
        // 解决纯图标用户不知道具体功能的问题（参考番茄/起点/Legado 做法）
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
          SizedBox(
            // 限制高度避免 Column 撑满 AppBar，宽度自适应内容
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                _buildActionBtn(
                  icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  label: _isBookmarked ? '已签' : '书签',
                  color: _isBookmarked ? Colors.amber : null,
                  onPressed: _loading ? null : _toggleBookmark,
                ),
                _buildActionBtn(
                  icon: Icons.auto_mode,
                  label: isAutoReading ? '停止' : '自动',
                  color: isAutoReading ? Colors.teal : null,
                  onPressed: _loading ? null : _toggleAutoRead,
                ),
                _buildActionBtn(
                  icon: ttsIcon,
                  label: _ttsState != TtsPlayState.stopped ? '朗读中' : '朗读',
                  color: _ttsState != TtsPlayState.stopped ? Colors.teal : null,
                  onPressed: _loading ? null : _toggleTts,
                ),
                _buildActionBtn(
                  icon: Icons.swap_horiz,
                  label: '换源',
                  onPressed: _loading ? null : _manualResolve,
                ),
                _buildActionBtn(
                  icon: Icons.download_for_offline,
                  label: '下载',
                  onPressed: _loading
                      ? null
                      : () => ChapterDownloadSheet.show(
                            context,
                            book: _currentBook,
                            chapters: _currentChapters,
                            currentIndex: _currentIndex,
                          ),
                ),
                _buildActionBtn(
                  icon: Icons.menu_book,
                  label: '笔记',
                  onPressed: _openNotesDrawer,
                ),
                _buildActionBtn(
                  icon: Icons.list,
                  label: '目录',
                  onPressed: () => _openChapterDrawer(),
                ),
                _buildActionBtn(
                  icon: Icons.tune,
                  label: '设置',
                  onPressed: () => _openSettingsSheet(),
                ),
              ],
            ),
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
                      child: _wrapBrightness(
                        prefs,
                        prefs.pageMode == PageMode.scroll
                            ? _buildScrollBody(prefs, bg)
                            : _buildPagedBody(prefs, bg),
                      ),
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
                          value: _ttsState != TtsPlayState.stopped
                              ? _ttsProgress
                              : progressPercent,
                          minHeight: 3,
                          backgroundColor: bg.foreground.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                            _ttsState != TtsPlayState.stopped
                                ? Colors.teal
                                : bg.foreground.withOpacity(0.5),
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

  /// 亮度遮罩：当用户设置了 brightness 时，叠加半透明黑色层模拟屏幕变暗。
  Widget _wrapBrightness(ReadingPrefs prefs, Widget child) {
    final b = prefs.brightness;
    if (b == null || b >= 1.0) return child;
    final dim = (1.0 - b).clamp(0.0, 0.7);
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withOpacity(dim)),
          ),
        ),
      ],
    );
  }

  /// 滚动模式正文：保留原 ListView + 上下章按钮。
  Widget _buildScrollBody(ReadingPrefs prefs, _Bg bg) {
    final raw = _content?.isNotEmpty == true ? _content! : '（本章内容为空）';
    final display = _displayText(raw, prefs);
    // NotificationListener 检测用户手动滚动 → 停止朗读自动跟随
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) {
          // dragDetails != null 表示用户手指拖动（程序 jumpTo 时为 null）
          if (n.dragDetails != null) {
            if (_autoFollowTts && _ttsState == TtsPlayState.speaking) {
              _autoFollowTts = false;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已停止跟随朗读滚动（点击朗读按钮恢复跟随）'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _displayText(_currentChapter.name, prefs),
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: bg.foreground,
              fontFamily: _fontFamilyFor(prefs.fontFamilyIndex)),
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
          onSelectionChanged: (selection) =>
              _lastSelection = selection?.plainText ?? '',
          contextMenuBuilder: (context, selectableRegionState) {
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: [
                ...selectableRegionState.contextMenuButtonItems,
                ContextMenuButtonItem(
                  label: '添加笔记',
                  onPressed: () {
                    selectableRegionState.hideToolbar();
                    _addNoteFromSelection(_lastSelection);
                  },
                ),
              ],
            );
          },
          child: Text.rich(
            _buildAnnotatedContent(display, bg, prefs),
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
      ),
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
        final raw = isCurrent
            ? (_content?.isNotEmpty == true ? _content! : '（本章内容为空）')
            : _currentChapters[index].name;
        final display = _displayText(raw, prefs);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayText(_currentChapters[index].name, prefs),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: bg.foreground,
                    fontFamily: _fontFamilyFor(prefs.fontFamilyIndex)),
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
                onSelectionChanged: (selection) =>
                    _lastSelection = selection?.plainText ?? '',
                contextMenuBuilder: (context, selectableRegionState) {
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableRegionState.contextMenuAnchors,
                    buttonItems: [
                      ...selectableRegionState.contextMenuButtonItems,
                      ContextMenuButtonItem(
                        label: '添加笔记',
                        onPressed: () {
                          selectableRegionState.hideToolbar();
                          _addNoteFromSelection(_lastSelection);
                        },
                      ),
                    ],
                  );
                },
                child: isCurrent
                    ? Text.rich(_buildAnnotatedContent(display, bg, prefs))
                    : Text(
                        display,
                        style: _contentStyle(bg, prefs),
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
  ///
  /// 阅读器由详情页 [context.push] 进入，这里直接 pop 即可回到详情页，
  /// 保留详情页的目录/进度状态。若栈为空（异常情况）则回退到搜书根页。
  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/search');
    }
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
                        color: ThemeColors.mutedText(context),
                        fontSize: 12,
                      )),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.isVolume ? ThemeColors.mutedText(context) : null,
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
    final maxHeight = MediaQuery.of(context).size.height * 0.78;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
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
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
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
                    child: Text(prefs.fontSize.toStringAsFixed(0),
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
                    child: Text(prefs.lineHeight.toStringAsFixed(1),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
              // 亮度
              Row(
                children: [
                  const SizedBox(width: 72, child: Text('亮度')),
                  Expanded(
                    child: Slider(
                      value: prefs.brightness ?? 1.0,
                      min: 0.3,
                      max: 1.0,
                      divisions: 14,
                      label:
                          ((prefs.brightness ?? 1.0) * 100).toStringAsFixed(0),
                      onChanged: (v) => notifier.setBrightness(v),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                        '${((prefs.brightness ?? 1.0) * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              // 自动阅读速度
              Row(
                children: [
                  const SizedBox(width: 72, child: Text('自动阅读')),
                  Expanded(
                    child: Slider(
                      value: prefs.autoReadSpeed.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      label: prefs.autoReadSpeed == 0
                          ? '关闭'
                          : '${prefs.autoReadSpeed} 行/分',
                      onChanged: (v) =>
                          notifier.setAutoReadSpeed(v.round()),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      prefs.autoReadSpeed == 0
                          ? '关闭'
                          : '${prefs.autoReadSpeed}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              // TTS 语速
              Row(
                children: [
                  const SizedBox(width: 72, child: Text('朗读语速')),
                  Expanded(
                    child: Slider(
                      value: prefs.ttsRate,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: '${prefs.ttsRate.toStringAsFixed(1)}x',
                      onChanged: notifier.setTtsRate,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${prefs.ttsRate.toStringAsFixed(1)}x',
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
              // TTS 音调
              Row(
                children: [
                  const SizedBox(width: 72, child: Text('朗读音调')),
                  Expanded(
                    child: Slider(
                      value: prefs.ttsPitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: prefs.ttsPitch.toStringAsFixed(1),
                      onChanged: notifier.setTtsPitch,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(prefs.ttsPitch.toStringAsFixed(1),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
              // TTS 发音人（edge_tts 多发音人选择）
              Row(
                children: [
                  const SizedBox(width: 72, child: Text('朗读发音人')),
                  Expanded(
                    child: DropdownButton<String>(
                      value: kEdgeTtsVoices
                              .any((v) => v.shortName == prefs.ttsVoice)
                          ? prefs.ttsVoice
                          : kDefaultEdgeVoice,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: kEdgeTtsVoices
                          .map((v) => DropdownMenuItem(
                                value: v.shortName,
                                child: Text(v.label, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) notifier.setTtsVoice(v);
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 72, top: 2),
                child: Text(
                  '神经网络语音需联网，音质优于系统 TTS',
                  style: TextStyle(
                      fontSize: 11, color: ThemeColors.mutedText(context)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('字体', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _fontLabels.length; i++)
                    ChoiceChip(
                      label: Text(_fontLabels[i]),
                      selected: prefs.fontFamilyIndex == i,
                      onSelected: (_) => notifier.setFontFamilyIndex(i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
                                : ThemeColors.mutedText(context),
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
              // 简繁切换
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('繁体中文'),
                subtitle:
                    const Text('开启后正文将以繁体显示', style: TextStyle(fontSize: 12)),
                value: prefs.traditionalChinese,
                onChanged: notifier.setTraditionalChinese,
              ),
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
      ),
    );
  }

  static const _fontLabels = <String>['系统', '衬线', '无衬线', '等宽'];

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

/// 文本区间辅助类（用于笔记高亮）。
class _TextRange {
  final int start;
  final int end;
  final Note note;
  const _TextRange(this.start, this.end, this.note);
}

/// 笔记 / 书签 列表抽屉。
class _NotesBookmarksSheet extends StatelessWidget {
  final List<Note> notes;
  final List<Bookmark> bookmarks;
  final int currentChapterIndex;
  final ValueChanged<int> onJumpBookmark;
  final ValueChanged<Note> onDeleteNote;

  const _NotesBookmarksSheet({
    required this.notes,
    required this.bookmarks,
    required this.currentChapterIndex,
    required this.onJumpBookmark,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: height,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Text('笔记 / 书签',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: '笔记'),
                Tab(text: '书签'),
              ],
              labelStyle: TextStyle(fontSize: 14),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildNotesTab(context),
                  _buildBookmarksTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesTab(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 56, color: ThemeColors.mutedText(context)),
            const SizedBox(height: 8),
            const Text('还没有笔记'),
            const SizedBox(height: 4),
            Text('在正文中长按选择文字即可添加笔记',
                style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final n = notes[i];
        final isCurrent = n.chapterIndex == currentChapterIndex;
        return ListTile(
          leading: Icon(
            Icons.format_quote,
            size: 18,
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : ThemeColors.mutedText(context),
          ),
          title: Text(
            n.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (n.thought != null && n.thought!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '感想：${n.thought}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                '${n.chapterName} · 第 ${n.chapterIndex + 1} 章',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.mutedText(context),
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除笔记'),
                  content: const Text('确定删除这条笔记？'),
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
              if (ok == true) onDeleteNote(n);
            },
          ),
          onTap: isCurrent ? null : () => onJumpBookmark(n.chapterIndex),
        );
      },
    );
  }

  Widget _buildBookmarksTab(BuildContext context) {
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 56, color: ThemeColors.mutedText(context)),
            const SizedBox(height: 8),
            const Text('还没有书签'),
            const SizedBox(height: 4),
            Text('点击右上角书签图标可加入书签',
                style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final b = bookmarks[i];
        final isCurrent = b.chapterIndex == currentChapterIndex;
        return ListTile(
          leading: Icon(
            Icons.bookmark,
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : Colors.amber,
            size: 20,
          ),
          title: Text(
            b.chapterName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: b.note != null && b.note!.isNotEmpty
              ? Text(b.note!, style: const TextStyle(fontSize: 12))
              : null,
          trailing: Text(
            '第 ${b.chapterIndex + 1} 章',
            style: TextStyle(fontSize: 11, color: ThemeColors.mutedText(context)),
          ),
          onTap: isCurrent ? null : () => onJumpBookmark(b.chapterIndex),
        );
      },
    );
  }
}

/// 添加笔记对话框：可输入感想。
class _AddNoteDialog extends StatefulWidget {
  final String selectedText;
  const _AddNoteDialog({required this.selectedText});

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, size: 20),
          SizedBox(width: 8),
          Text('添加笔记', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('划线内容',
                style: TextStyle(fontSize: 12, color: ThemeColors.mutedText(context))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  widget.selectedText,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('感想（可选）',
                style: TextStyle(fontSize: 12, color: ThemeColors.mutedText(context))),
            const SizedBox(height: 4),
            TextField(
              controller: _controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '写下你的想法…',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
