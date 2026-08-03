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
import 'package:book_reader/ui/explore/explore_category_page.dart';
import 'package:book_reader/ui/explore/explore_source_page.dart';
import 'package:book_reader/ui/search/search_page.dart';
import 'package:book_reader/ui/settings/backup_page.dart';
import 'package:book_reader/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


/// 全局路由配置。
///
/// - 主导航（书架/搜书）使用 [ShellRoute] + 底部 [NavigationBar]，
///   保证在书架和搜书间切换时不丢失页面状态。
/// - 详情页 `/book` 也包含在 Shell 内，方便用户随时切回书架。
/// - 其他次级页面（书源管理、阅读器、设置等）作为全屏独立路由。
final appRouter = GoRouter(
  initialLocation: '/search',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/shelf',
          builder: (context, state) => const BookshelfPage(),
        ),
        GoRoute(
          path: '/discover',
          builder: (context, state) => const DiscoverPage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/me',
          builder: (context, state) => const SettingsPage(),
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
      ],
    ),
    // 书源管理：全屏页面，从搜书页 AppBar 进入
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
      path: '/explore',
      builder: (context, state) => const ExploreSourcePage(),
    ),
    GoRoute(
      path: '/explore-category',
      builder: (context, state) {
        final source = state.extra as BookSource?;
        if (source == null) {
          return const Scaffold(body: Center(child: Text('参数缺失')));
        }
        return ExploreCategoryPage(source: source);
      },
    ),
    // /discover 与 /settings 已并入主页 4 Tab（/discover、/me），
    // 保留 /settings 兼容旧链接跳转到 /me。
    GoRoute(
      path: '/settings',
      redirect: (context, state) => '/me',
    ),
    GoRoute(
      path: '/backup',
      builder: (context, state) => const BackupPage(),
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

/// 主页底部导航容器：书架 / 发现 / 搜书 / 我的。
///
/// 详情页 /book 也包含在 Shell 内，方便用户随时切到书架查看收藏。
class _HomeShell extends StatelessWidget {
  final Widget child;
  const _HomeShell({required this.child});

  /// 底部导航 tab：路径前缀。
  static const _tabs = <String>[
    '/shelf',
    '/discover',
    '/search',
    '/me',
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // 详情页 /book 不属于任何 tab，回落到搜书（更常见的来源）
    int idx = _tabs.indexWhere((t) => location.startsWith(t));
    if (idx < 0) idx = 2; // 默认搜书
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_outlined),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: '搜书',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
