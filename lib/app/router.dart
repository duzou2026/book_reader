import 'package:book_reader/ui/book_sources/book_sources_page.dart';
import 'package:book_reader/ui/search/search_page.dart';
import 'package:go_router/go_router.dart';

/// 全局路由配置。
final appRouter = GoRouter(
  initialLocation: '/search',
  routes: [
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchPage(),
    ),
    GoRoute(
      path: '/book-sources',
      builder: (context, state) => const BookSourcesPage(),
    ),
  ],
);
