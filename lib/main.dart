import 'dart:convert';

import 'package:book_reader/app/providers.dart';
import 'package:book_reader/app/router.dart';
import 'package:book_reader/data/demo_book_sources.dart';
import 'package:book_reader/services/preferences/theme_prefs_repository.dart';
import 'package:book_reader/ui/settings/app_update_controller.dart';
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
  // 首次启动：内置 demo 书源（disabled + demo 分组），让 App 不空
  await _seedDemoBookSources(bookSourceBox);
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

/// 仅在 `book_sources` Box 为空时写入 demo 书源。
///
/// 已经导入过书源（或曾经手动删除过 demo 书源）的用户不会再次写入，
/// 避免覆盖用户的现有配置。
Future<void> _seedDemoBookSources(Box<String> box) async {
  if (box.isNotEmpty) return;
  for (final s in demoBookSources) {
    await box.put(s.bookSourceUrl, jsonEncode(s.toJson()));
  }
}

class BookReaderApp extends ConsumerStatefulWidget {
  const BookReaderApp({super.key});

  @override
  ConsumerState<BookReaderApp> createState() => _BookReaderAppState();
}

class _BookReaderAppState extends ConsumerState<BookReaderApp> {
  final _appKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 启动后异步静默检查更新（不阻塞首屏渲染）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _appKey.currentContext;
      if (ctx != null) {
        AppUpdateController.checkOnStartup(ctx, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(themePrefsProvider);
    final seed = Color(prefs.seedColor);
    return MaterialApp.router(
      key: _appKey,
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
