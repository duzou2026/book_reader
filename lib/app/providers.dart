import 'package:book_reader/data/hive_book_source_repository.dart';
import 'package:book_reader/domain/usecases/get_book_info.dart';
import 'package:book_reader/domain/usecases/get_chapter_content.dart';
import 'package:book_reader/domain/usecases/search_books.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_engine.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 书源持久化 Box。在 main.dart 中通过 [ProviderScope.overrides] 注入。
final bookSourceBoxProvider = Provider<Box<String>>((ref) {
  throw UnimplementedError('bookSourceBoxProvider 必须在 main.dart 中 override');
});

final bookSourceRepositoryProvider = Provider<BookSourceRepository>((ref) {
  final box = ref.watch(bookSourceBoxProvider);
  return HiveBookSourceRepository(box);
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
