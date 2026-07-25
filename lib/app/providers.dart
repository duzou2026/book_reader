import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/bookmarks_repository.dart';
import 'package:book_reader/data/hive_book_source_repository.dart';
import 'package:book_reader/data/notes_repository.dart';
import 'package:book_reader/data/reading_history_repository.dart';
import 'package:book_reader/data/reading_stats_repository.dart';
import 'package:book_reader/data/search_history_repository.dart';
import 'package:book_reader/domain/usecases/check_book_updates.dart';
import 'package:book_reader/domain/usecases/discover_books.dart';
import 'package:book_reader/domain/usecases/get_audio.dart';
import 'package:book_reader/domain/usecases/get_book_info.dart';
import 'package:book_reader/domain/usecases/get_chapter_content.dart';
import 'package:book_reader/domain/usecases/get_related_books.dart';
import 'package:book_reader/domain/usecases/resolve_chapter_content.dart';
import 'package:book_reader/domain/usecases/search_books.dart';
import 'package:book_reader/domain/usecases/test_book_source.dart';
import 'package:book_reader/services/audio/audio_player_notifier.dart';
import 'package:book_reader/services/audio/audio_toc_fetcher.dart';
import 'package:book_reader/services/audio/audio_url_fetcher.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
import 'package:book_reader/services/book_info/cross_source_content_resolver.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/preferences/reading_progress_repository.dart';
import 'package:book_reader/services/preferences/reading_prefs_repository.dart';
import 'package:book_reader/services/tts/tts_service.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
import 'package:book_reader/services/search/search_result_cache.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

/// 书源持久化 Box。在 main.dart 中通过 [ProviderScope.overrides] 注入。
final bookSourceBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('bookSourceBoxProvider 必须在 main.dart 中 override');
});

/// 书架 Box。
final bookshelfBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('bookshelfBoxProvider 必须在 main.dart 中 override');
});

/// 阅读进度 Box。
final readingProgressBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'readingProgressBoxProvider 必须在 main.dart 中 override');
});

/// 阅读偏好 Box（全局字号/行距/背景等）。
final readingPrefsBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'readingPrefsBoxProvider 必须在 main.dart 中 override');
});

/// 搜索历史 Box。
final searchHistoryBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'searchHistoryBoxProvider 必须在 main.dart 中 override');
});

/// 笔记 Box。
final notesBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'notesBoxProvider 必须在 main.dart 中 override');
});

/// 书签 Box。
final bookmarksBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'bookmarksBoxProvider 必须在 main.dart 中 override');
});

/// 阅读统计 Box。
final readingStatsBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'readingStatsBoxProvider 必须在 main.dart 中 override');
});

/// 阅读历史 Box。
final readingHistoryBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError(
      'readingHistoryBoxProvider 必须在 main.dart 中 override');
});

final bookSourceRepositoryProvider = Provider<BookSourceRepository>((ref) {
  final box = ref.watch(bookSourceBoxProvider);
  return HiveBookSourceRepository(box);
});

final bookshelfRepositoryProvider = Provider<BookshelfRepository>((ref) {
  final box = ref.watch(bookshelfBoxProvider);
  return BookshelfRepository(box);
});

final readingProgressRepositoryProvider =
    Provider<ReadingProgressRepository>((ref) {
  final box = ref.watch(readingProgressBoxProvider);
  return ReadingProgressRepository(box);
});

final readingPrefsRepositoryProvider =
    Provider<ReadingPrefsRepository>((ref) {
  final box = ref.watch(readingPrefsBoxProvider);
  return ReadingPrefsRepository(box);
});

final searchHistoryRepositoryProvider =
    Provider<SearchHistoryRepository>((ref) {
  final box = ref.watch(searchHistoryBoxProvider);
  return SearchHistoryRepository(box);
});

final hotKeywordsRepositoryProvider = Provider<HotKeywordsRepository>((ref) {
  return HotKeywordsRepository(ref.watch(searchHistoryRepositoryProvider));
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(notesBoxProvider));
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.watch(bookmarksBoxProvider));
});

final readingStatsRepositoryProvider = Provider<ReadingStatsRepository>((ref) {
  return ReadingStatsRepository(ref.watch(readingStatsBoxProvider));
});

final readingHistoryRepositoryProvider =
    Provider<ReadingHistoryRepository>((ref) {
  return ReadingHistoryRepository(ref.watch(readingHistoryBoxProvider));
});

/// TTS 服务（默认 NoOp，移动端可 override 为 flutter_tts 实现）。
final ttsServiceProvider = Provider<TtsService>((ref) {
  return NoOpTtsService();
});

/// 全局阅读偏好（响应式）：所有页面共享同一份偏好。
final readingPrefsProvider =
    StateNotifierProvider<ReadingPrefsNotifier, ReadingPrefs>((ref) {
  final repo = ref.watch(readingPrefsRepositoryProvider);
  return ReadingPrefsNotifier(repo);
});

final fetcherProvider = Provider<BookSourceFetcher>((ref) {
  return DioBookSourceFetcher();
});

final ruleEngineProvider = Provider<RuleEngine>((ref) {
  return RuleEngine();
});

final singleSourceSearcherProvider = Provider<SingleSourceSearcher>((ref) {
  return SingleSourceSearcher(
    fetcher: ref.watch(fetcherProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
  );
});

final searchAggregatorProvider = Provider<SearchAggregator>((ref) {
  return SearchAggregator(searcher: ref.watch(singleSourceSearcherProvider));
});

/// 搜索结果缓存（内存，跨页面共享）。
final searchResultCacheProvider = Provider<SearchResultCache>((ref) {
  return SearchResultCache();
});

final searchBooksProvider = Provider<SearchBooks>((ref) {
  return SearchBooks(
    aggregator: ref.watch(searchAggregatorProvider),
    repository: ref.watch(bookSourceRepositoryProvider),
  );
});

final bookInfoFetcherProvider = Provider<BookInfoFetcher>((ref) {
  return BookInfoFetcher(
    fetcher: ref.watch(fetcherProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
  );
});

final tocFetcherProvider = Provider<TocFetcher>((ref) {
  return TocFetcher(
    fetcher: ref.watch(fetcherProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
  );
});

final getBookInfoProvider = Provider<GetBookInfo>((ref) {
  return GetBookInfo(
    fetcher: ref.watch(bookInfoFetcherProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

final getTocProvider = Provider<GetToc>((ref) {
  return GetToc(
    fetcher: ref.watch(tocFetcherProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

final contentFetcherProvider = Provider<ContentFetcher>((ref) {
  return ContentFetcher(
    fetcher: ref.watch(fetcherProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
  );
});

final getChapterContentProvider = Provider<GetChapterContent>((ref) {
  return GetChapterContent(
    fetcher: ref.watch(contentFetcherProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

final crossSourceContentResolverProvider = Provider<CrossSourceContentResolver>(
    (ref) {
  return CrossSourceContentResolver(
    tocFetcher: ref.watch(tocFetcherProvider),
    contentFetcher: ref.watch(contentFetcherProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

final resolveChapterContentProvider = Provider<ResolveChapterContent>((ref) {
  return ResolveChapterContent(
    getContent: ref.watch(getChapterContentProvider),
    resolver: ref.watch(crossSourceContentResolverProvider),
  );
});

final testBookSourceProvider = Provider<TestBookSource>((ref) {
  return TestBookSource(
    searcher: ref.watch(singleSourceSearcherProvider),
    bookInfoFetcher: ref.watch(bookInfoFetcherProvider),
    tocFetcher: ref.watch(tocFetcherProvider),
    contentFetcher: ref.watch(contentFetcherProvider),
  );
});

/// 检查书架追更。
final checkBookUpdatesProvider = Provider<CheckBookUpdates>((ref) {
  return CheckBookUpdates(
    getToc: ref.watch(getTocProvider),
    repo: ref.watch(bookshelfRepositoryProvider),
  );
});

/// 发现/排行用例。
final discoverBooksProvider = Provider<DiscoverBooks>((ref) {
  return DiscoverBooks(
    aggregator: ref.watch(searchAggregatorProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

/// 相关推荐用例 (D-2)。
final getRelatedBooksProvider = Provider<GetRelatedBooks>((ref) {
  return GetRelatedBooks(
    aggregator: ref.watch(searchAggregatorProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

final audioTocFetcherProvider = Provider<AudioTocFetcher>((ref) {
  return AudioTocFetcher(
    fetcher: ref.watch(fetcherProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
  );
});

final audioUrlFetcherProvider = Provider<AudioUrlFetcher>((ref) {
  return AudioUrlFetcher(
    fetcher: ref.watch(fetcherProvider),
    ruleEngine: ref.watch(ruleEngineProvider),
  );
});

final getAudioTocProvider = Provider<GetAudioToc>((ref) {
  return GetAudioToc(
    fetcher: ref.watch(audioTocFetcherProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

final getAudioUrlProvider = Provider<GetAudioUrl>((ref) {
  return GetAudioUrl(
    fetcher: ref.watch(audioUrlFetcherProvider),
    getEnabledSources: () =>
        ref.watch(bookSourceRepositoryProvider).getEnabledSources(),
  );
});

/// just_audio 的 [AudioPlayer] 单例。
/// refDispose 时自动释放原生资源。
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// 全局播放器状态 Notifier。
final audioPlayerNotifierProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  final player = ref.watch(audioPlayerProvider);
  final getAudioUrl = ref.watch(getAudioUrlProvider);
  return AudioPlayerNotifier(
    player,
    CallbackAudioUrlResolver((info, chapter) => getAudioUrl(info, chapter)),
  );
});
