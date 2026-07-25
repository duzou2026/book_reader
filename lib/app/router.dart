import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/ui/audio/audio_player_page.dart';
import 'package:book_reader/ui/book/book_detail_page.dart';
import 'package:book_reader/ui/book/bookshelf_page.dart';
import 'package:book_reader/ui/book/discover_page.dart';
import 'package:book_reader/ui/book/reader_page.dart';
import 'package:book_reader/ui/book/reading_history_page.dart';
import 'package:book_reader/ui/book_sources/book_source_edit_page.dart';
import 'package:book_reader/ui/book_sources/book_sources_page.dart';
import 'package:book_reader/ui/search/search_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 全局路由配置。
final appRouter = GoRouter(
  initialLocation: '/shelf',
  routes: [
    GoRoute(
      path: '/shelf',
      builder: (context, state) => const BookshelfPage(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/book-sources',
      builder: (context, state) => const BookSourcesPage(),
    ),
    GoRoute(
      path: '/book-source-edit',
      builder: (context, state) {
        final initial = state.extra as BookSource?;
        return BookSourceEditPage(initial: initial);
      },
    ),
    GoRoute(
      path: '/reading-history',
      builder: (context, state) => const ReadingHistoryPage(),
    ),
    GoRoute(
      path: '/discover',
      builder: (context, state) => const DiscoverPage(),
    ),
    GoRoute(
      path: '/book',
      builder: (context, state) {
        final result = state.extra as SearchResult?;
        if (result == null) {
          return const Scaffold(body: Center(child: Text('参数缺失')));
        }
        return BookDetailPage(searchResult: result);
      },
    ),
    GoRoute(
      path: '/reader',
      builder: (context, state) {
        final args = state.extra as ReaderArgs?;
        if (args == null) {
          return const Scaffold(body: Center(child: Text('参数缺失')));
        }
        return ReaderPage(args: args);
      },
    ),
    GoRoute(
      path: '/audio',
      builder: (context, state) {
        final args = state.extra as AudioPlayerArgs?;
        if (args == null) {
          return const Scaffold(body: Center(child: Text('参数缺失')));
        }
        return AudioPlayerPage(args: args);
      },
    ),
  ],
);
