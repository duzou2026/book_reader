import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/audio_chapter.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 有声书播放器入参。
class AudioPlayerArgs {
  final BookInfo book;
  final List<AudioChapter> chapters;
  final int initialIndex;
  const AudioPlayerArgs({
    required this.book,
    required this.chapters,
    required this.initialIndex,
  });
}

class AudioPlayerPage extends ConsumerStatefulWidget {
  final AudioPlayerArgs args;
  const AudioPlayerPage({super.key, required this.args});

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> {
  @override
  void initState() {
    super.initState();
    // 启动播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(audioPlayerNotifierProvider.notifier);
      notifier.playList(widget.args.book, widget.args.chapters, widget.args.initialIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerNotifierProvider);
    final notifier = ref.read(audioPlayerNotifierProvider.notifier);
    final chapter = state.currentChapter;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/book',
              extra: _toSearchResult(widget.args.book)),
        ),
        title: Text(chapter?.name ?? '听书',
            style: const TextStyle(fontSize: 14)),
      ),
      body: state.playlist.isEmpty
          ? const Center(child: Text('播放列表为空'))
          : Column(
              children: [
                // 封面 + 书名
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.headphones,
                            size: 80, color: Colors.teal),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.book?.name ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.book?.author ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(state.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                // 进度条
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(_fmt(state.position),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Expanded(
                        child: Slider(
                          value: state.position.inMilliseconds.toDouble(),
                          max: (state.duration.inMilliseconds > 0
                                  ? state.duration.inMilliseconds
                                  : 1)
                              .toDouble(),
                          onChanged: state.duration.inMilliseconds > 0
                              ? (v) => notifier.seekTo(
                                  Duration(milliseconds: v.toInt()))
                              : null,
                        ),
                      ),
                      Text(_fmt(state.duration),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                // 控制按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: state.index > 0 ? notifier.previous : null,
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 36,
                        color: Colors.white,
                        icon: state.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(state.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow),
                        onPressed: () {
                          if (state.isPlaying) {
                            notifier.pause();
                          } else {
                            notifier.play();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_next),
                      onPressed: state.index + 1 < state.playlist.length
                          ? notifier.next
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 章节列表
                const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text('章节列表 (${state.playlist.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.playlist.length,
                    itemBuilder: (context, i) {
                      final c = state.playlist[i];
                      final isCurrent = i == state.index;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isCurrent ? Icons.graphic_eq : Icons.music_note,
                          size: 18,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: Text(c.name,
                            style: TextStyle(
                                fontSize: 14,
                                color: isCurrent
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        onTap: () => notifier.playList(
                            widget.args.book, widget.args.chapters, i),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  SearchResult _toSearchResult(BookInfo info) {
    return SearchResult(
      bookName: info.name ?? '',
      author: info.author ?? '',
      coverUrl: info.coverUrl,
      intro: info.intro,
      kind: info.kind,
      wordCount: info.wordCount,
      lastChapter: info.lastChapter,
      sources: [
        SearchSource(
          sourceName: info.sourceName,
          sourceUrl: info.sourceUrl,
          bookUrl: info.url,
        ),
      ],
    );
  }
}
