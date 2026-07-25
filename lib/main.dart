import 'package:book_reader/app/providers.dart';
import 'package:book_reader/app/router.dart';
import 'package:book_reader/services/preferences/theme_prefs_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  final bookSourceBox = await Hive.openBox<String>('book_sources');
  final bookshelfBox =
      await Hive.openBox<String>('bookshelf');
  final readingProgressBox =
      await Hive.openBox<String>('reading_progress');
  final readingPrefsBox =
      await Hive.openBox<String>('reading_prefs');
  final searchHistoryBox =
      await Hive.openBox<String>('search_history');
  final notesBox = await Hive.openBox<String>('notes');
  final bookmarksBox = await Hive.openBox<String>('bookmarks');
  final readingStatsBox = await Hive.openBox<String>('reading_stats');
  final readingHistoryBox = await Hive.openBox<String>('reading_history');
  final chapterCacheBox = await Hive.openBox<String>('chapter_cache');
  runApp(
    ProviderScope(
      overrides: [
        bookSourceBoxProvider.overrideWithValue(bookSourceBox),
        bookshelfBoxProvider.overrideWithValue(bookshelfBox),
        readingProgressBoxProvider.overrideWithValue(readingProgressBox),
        readingPrefsBoxProvider.overrideWithValue(readingPrefsBox),
        searchHistoryBoxProvider.overrideWithValue(searchHistoryBox),
        notesBoxProvider.overrideWithValue(notesBox),
        bookmarksBoxProvider.overrideWithValue(bookmarksBox),
        readingStatsBoxProvider.overrideWithValue(readingStatsBox),
        readingHistoryBoxProvider.overrideWithValue(readingHistoryBox),
        chapterCacheBoxProvider.overrideWithValue(chapterCacheBox),
      ],
      child: const BookReaderApp(),
    ),
  );
}

class BookReaderApp extends ConsumerWidget {
  const BookReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePrefsProvider);
    final seed = Color(prefs.seedColor);
    return MaterialApp.router(
      title: 'Book Reader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: _toMaterialThemeMode(prefs.mode),
      routerConfig: appRouter,
    );
  }

  ThemeMode _toMaterialThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}
