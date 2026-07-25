import 'dart:convert';

import 'package:book_reader/app/providers.dart';
import 'package:book_reader/app/router.dart';
import 'package:book_reader/data/remote_book_sources.dart';
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
  // 首次启动：从 GitHub 仓库远程拉取书源写入 Hive
  // - 已有书源的用户不会再次写入，避免覆盖用户配置
  // - 拉取失败时静默忽略，App 仍能启动（用户可在书源管理页点「刷新书源」重试）
  await _seedRemoteBookSources(bookSourceBox);
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

/// 仅在 `book_sources` Box 为空时，从 GitHub 仓库远程拉取书源写入。
///
/// 流程：
///   1. Box 非空 → 已有书源（用户配置过），跳过
///   2. Box 为空 → 通过 [RemoteBookSources] 拉取远程 JSON
///      - 拉取成功 → 缓存到 box 的 `xiu2_sources` key + 逐条写入各书源 URL
///      - 拉取失败 → 静默忽略，App 启动后用户可在书源管理页重试
Future<void> _seedRemoteBookSources(Box<String> box) async {
  if (box.isNotEmpty) return;
  final fetcher = RemoteBookSources(cacheBox: box);
  final sources = await fetcher.fetch(forceRefresh: true);
  for (final s in sources) {
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
