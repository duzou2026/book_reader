import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/hive_book_source_repository.dart';
import 'package:book_reader/domain/usecases/get_audio.dart';
import 'package:book_reader/domain/usecases/get_book_info.dart';
import 'package:book_reader/domain/usecases/get_chapter_content.dart';
import 'package:book_reader/domain/usecases/resolve_chapter_content.dart';
import 'package:book_reader/domain/usecases/search_books.dart';
import 'package:book_reader/services/audio/audio_player_notifier.dart';
import 'package:book_reader/services/audio/audio_toc_fetcher.dart';
import 'package:book_reader/services/audio/audio_url_fetcher.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
import 'package:book_reader/services/book_info/cross_source_content_resolver.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/preferences/reading_prefs_repository.dart';
import 'package:book_reader/services/preferences/reading_progress_repository.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
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
