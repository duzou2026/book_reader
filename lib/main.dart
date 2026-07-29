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
  final bookSourcesCacheBox =
      await Hive.openBox<String>('book_sources_cache');
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
  // 迁移：清除 book_sources box 中误写的缓存 key（历史 bug 遗留）
  // 旧版 RemoteBookSources 把 List JSON 写入 box['xiu2_sources']，
  // 导致 HiveBookSourceRepository.getAll() 遍历到该 value 时
  // `as Map<String, dynamic>` 崩溃。改用独立 cache box 后需清理脏数据。
  await _migrateCleanStaleCacheKey(bookSourceBox);
  // 首次启动：从 GitHub 仓库远程拉取书源写入 Hive
  // - 已有书源的用户不会再次写入，避免覆盖用户配置
  // - 拉取失败时静默忽略，App 仍能启动（用户可在书源管理页点「刷新书源」重试）
  await _seedRemoteBookSources(bookSourceBox, bookSourcesCacheBox);
  runApp(
    ProviderScope(
      overrides: [
        bookSourceBoxProvider.overrideWithValue(bookSourceBox),
        bookSourcesCacheBoxProvider.overrideWithValue(bookSourcesCacheBox),
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
///      - 拉取成功 → 缓存到独立的 [cacheBox] + 逐条写入各书源 URL 到 [box]
///      - 拉取失败 → 静默忽略，App 启动后用户可在书源管理页重试
Future<void> _seedRemoteBookSources(
    Box<String> box, Box<String> cacheBox) async {
  if (box.isNotEmpty) return;
  final fetcher = RemoteBookSources(cacheBox: cacheBox);
  final sources = await fetcher.fetch(forceRefresh: true);
  for (final s in sources) {
    await box.put(s.bookSourceUrl, jsonEncode(s.toJson()));
  }
}

/// 迁移：清除 `book_sources` box 中误写的缓存 key。
///
/// 旧版本把远程书源 List JSON 写入 `box['xiu2_sources']`，导致
/// `HiveBookSourceRepository.getAll()` 遍历到该 value 时
/// `jsonDecode(s) as Map<String, dynamic>` 崩溃。
/// 改用独立 cache box 后，需删除遗留的脏 key。
Future<void> _migrateCleanStaleCacheKey(Box<String> box) async {
  await box.delete('xiu2_sources');
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
    final lightScheme = ColorScheme.fromSeed(seedColor: seed);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return MaterialApp.router(
      key: _appKey,
      title: 'Book Reader',
      theme: _buildTheme(lightScheme, Brightness.light),
      darkTheme: _buildTheme(darkScheme, Brightness.dark),
      themeMode: _toMaterialThemeMode(prefs.mode),
      routerConfig: appRouter,
    );
  }

  /// 构建精致主题：统一圆角、阴影、字号层级、AppBar 风格。
  ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // AppBar：无阴影、透明背景、大标题
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      // 卡片：圆角 + 柔和阴影
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      // 列表项：更舒适的留白
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      // 分割线：更柔和
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        thickness: 0.5,
        space: 0.5,
      ),
      // 输入框：圆角填充式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      // 按钮：圆角
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      // 底部导航：精致
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w500),
        ),
      ),
      // 芯片：圆角
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      // 文本字号层级
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13, height: 1.5),
        bodySmall: TextStyle(fontSize: 11, height: 1.4),
      ),
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
