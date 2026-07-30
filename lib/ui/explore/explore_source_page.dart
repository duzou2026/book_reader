import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/explore/explore_url_parser.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 书源浏览入口页：列出所有支持「发现/分类浏览」的书源。
///
/// 仅展示同时满足以下条件的书源：
///   - enabled == true
///   - exploreUrl 非空
///   - ruleExplore.bookList 非空（有解析规则才能抓到书）
///
/// 点击某书源进入 [ExploreCategoryPage] 按分类浏览。
class ExploreSourcePage extends ConsumerStatefulWidget {
  const ExploreSourcePage({super.key});

  @override
  ConsumerState<ExploreSourcePage> createState() => _ExploreSourcePageState();
}

class _ExploreSourcePageState extends ConsumerState<ExploreSourcePage> {
  late Future<List<BookSource>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(bookSourceRepositoryProvider).getAll();
  }

  /// 判断书源是否支持分类浏览。
  bool _supportsExplore(BookSource s) {
    if (!s.enabled) return false;
    final url = s.exploreUrl;
    if (url == null || url.trim().isEmpty) return false;
    final rule = s.ruleExplore;
    if (rule == null || rule.bookList == null || rule.bookList!.trim().isEmpty) {
      return false;
    }
    // 至少要能解析出一个可抓取的分类（url 非空）
    final cats = ExploreUrlParser.parse(url);
    return cats.any((c) => !c.isHeader);
  }

  void _openSource(BookSource source) {
    context.push('/explore-category', extra: source);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源浏览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => setState(_reload),
          ),
        ],
      ),
      body: FutureBuilder<List<BookSource>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final all = snapshot.data ?? const [];
          final list = all.where(_supportsExplore).toList();
          if (list.isEmpty) {
            return _buildEmpty(context);
          }
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '共 ${list.length} 个支持浏览的书源',
                    style: TextStyle(
                        color: ThemeColors.mutedText(context), fontSize: 13),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final catCount =
                        ExploreUrlParser.parse(s.exploreUrl).length;
                    return ListTile(
                      leading: const Icon(Icons.library_books_outlined),
                      title: Text(s.bookSourceName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.bookSourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: ThemeColors.mutedText(context),
                                fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$catCount 个分类',
                            style: TextStyle(
                                color: ThemeColors.mutedText(context),
                                fontSize: 11),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openSource(s),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore_off,
              size: 64, color: ThemeColors.mutedText(context)),
          const SizedBox(height: 12),
          const Text('暂无支持浏览的书源'),
          const SizedBox(height: 6),
          Text(
            '需要书源配置了 exploreUrl 和 ruleExplore.bookList',
            style: TextStyle(
                color: ThemeColors.mutedText(context), fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/book-sources'),
            icon: const Icon(Icons.library_books),
            label: const Text('去书源管理'),
          ),
        ],
      ),
    );
  }
}
