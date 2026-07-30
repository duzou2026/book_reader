import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/services/explore/explore_url_parser.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 分类浏览页：在指定书源内按分类浏览书籍。
///
/// - 顶部横向滚动的分类 Tab（从 exploreUrl 解析得到，仅展示可抓取的分类）
/// - Tab 切换加载该分类第 1 页书籍
/// - 书籍以网格展示（封面 + 书名 + 作者），点击进入 /book 详情页
/// - 滚动到底部自动加载下一页（page+1）
/// - 加载中显示 loading，失败显示错误提示 + 重试
class ExploreCategoryPage extends ConsumerStatefulWidget {
  final BookSource source;

  const ExploreCategoryPage({super.key, required this.source});

  @override
  ConsumerState<ExploreCategoryPage> createState() =>
      _ExploreCategoryPageState();
}

class _ExploreCategoryPageState extends ConsumerState<ExploreCategoryPage> {
  /// 可抓取的分类（url 非空）。
  late final List<ExploreCategory> _categories;

  int _selected = 0;
  List<SearchResult> _results = const [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final all = ExploreUrlParser.parse(widget.source.exploreUrl);
    _categories = all.where((c) => !c.isHeader).toList();
    _scrollController.addListener(_onScroll);
    if (_categories.isNotEmpty) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_loading &&
        !_loadingMore &&
        _hasMore &&
        _error == null) {
      _loadMore();
    }
  }

  /// 加载当前分类第 1 页（重置状态）。
  Future<void> _load({bool reset = false}) async {
    if (_categories.isEmpty) return;
    final category = _categories[_selected];
    setState(() {
      _loading = true;
      _error = null;
      _results = const [];
      _page = 1;
      _hasMore = true;
    });
    try {
      final list = await ref.read(exploreBooksProvider).fetchCategory(
            widget.source,
            category,
            page: 1,
          );
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
        // 第 1 页为空或不足一屏，认为没有更多
        _hasMore = list.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 加载下一页并追加。
  Future<void> _loadMore() async {
    if (_categories.isEmpty) return;
    final category = _categories[_selected];
    final nextPage = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final list = await ref.read(exploreBooksProvider).fetchCategory(
            widget.source,
            category,
            page: nextPage,
          );
      if (!mounted) return;
      setState(() {
        if (list.isEmpty) {
          _hasMore = false;
        } else {
          _results = [..._results, ...list];
          _page = nextPage;
          // 返回不足预期则停止翻页（避免无限空翻）
          if (list.length < 10) _hasMore = false;
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      // 翻页失败不重置，仅提示
      _showSnack('加载下一页失败');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _switchCategory(int index) {
    if (index == _selected) return;
    setState(() => _selected = index);
    _load(reset: true);
  }

  void _openBook(SearchResult r) {
    context.push('/book', extra: r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.bookSourceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loading ? null : () => _load(reset: true),
          ),
        ],
      ),
      body: _categories.isEmpty
          ? _buildNoCategories(context)
          : Column(
              children: [
                _buildCategoryBar(),
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  /// 顶部横向滚动的分类 Tab。
  Widget _buildCategoryBar() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final c = _categories[i];
          final selected = i == _selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(c.title.isEmpty ? '未命名' : c.title),
              selected: selected,
              onSelected: (_) => _switchCategory(i),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _load(reset: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.inbox,
                size: 64, color: ThemeColors.mutedText(context)),
            const SizedBox(height: 12),
            const Text('该分类暂无结果', textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _results.length + (_loadingMore || _hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _results.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingMore
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Text('加载中...',
                        style: TextStyle(
                            color: ThemeColors.mutedText(context),
                            fontSize: 12)),
              ),
            );
          }
          final r = _results[i];
          return _BookGridTile(result: r, onTap: () => _openBook(r));
        },
      ),
    );
  }

  Widget _buildNoCategories(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined,
              size: 64, color: ThemeColors.mutedText(context)),
          const SizedBox(height: 12),
          const Text('该书源没有可浏览的分类'),
          const SizedBox(height: 6),
          Text(
            'exploreUrl 未配置或无可抓取分类',
            style: TextStyle(
                color: ThemeColors.mutedText(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 书籍网格单元：封面 + 书名 + 作者。
class _BookGridTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _BookGridTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = result.coverUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: cover != null
                  ? Image.network(
                      cover,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          _placeholder(context),
                    )
                  : _placeholder(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.bookName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            result.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11, color: ThemeColors.mutedText(context)),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: ThemeColors.surfaceLevel2(context),
      width: double.infinity,
      height: double.infinity,
      child: const Icon(Icons.book, color: Colors.white54),
    );
  }
}
