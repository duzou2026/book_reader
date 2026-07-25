import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/data/search_history_repository.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
import 'package:book_reader/services/search/search_result_cache.dart';
import 'package:book_reader/ui/search/search_result_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  /// 原始搜索结果（未排序/筛选）。
  List<SearchResult> _rawResults = const [];

  /// 当前生效的关键词。
  String _lastKeyword = '';

  bool _loading = false;
  String? _error;

  /// 搜索进度（null 表示未在搜索或无源）。
  SearchProgress? _progress;

  /// 是否已展示过结果（区分「初始空态」和「搜索后无结果」）。
  bool _hasSearched = false;

  /// 当前结果是否来自缓存。
  bool _fromCache = false;

  /// 搜索历史。
  List<SearchHistoryEntry> _history = const [];

  /// 热门词。
  List<String> _hot = const [];

  /// 排序方式。
  SearchResultSort _sort = SearchResultSort.sourceCount;

  /// 当前书源筛选（null = 全部）。
  String? _filterSourceUrl;

  /// 当前分类筛选（null = 全部）。
  String? _filterKind;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final historyRepo = ref.read(searchHistoryRepositoryProvider);
    final hotRepo = ref.read(hotKeywordsRepositoryProvider);
    final history = await historyRepo.getAll();
    final hot = await hotRepo.getHot();
    if (!mounted) return;
    setState(() {
      _history = history;
      _hot = hot;
    });
  }

  Future<void> _search({String? keyword, bool forceRefresh = false}) async {
    final kw = (keyword ?? _controller.text).trim();
    if (kw.isEmpty) return;
    _controller.text = kw;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: kw.length));
    setState(() {
      _loading = true;
      _error = null;
      _progress = null;
      _hasSearched = true;
      _lastKeyword = kw;
      _filterSourceUrl = null;
      _filterKind = null;
    });
    // 缓存命中（非强制刷新时）
    if (!forceRefresh) {
      final cached = ref.read(searchResultCacheProvider).get(kw);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _rawResults = cached;
          _fromCache = true;
          _loading = false;
        });
        // 仍记录搜索历史
        await ref.read(searchHistoryRepositoryProvider).record(kw);
        await _loadSuggestions();
        return;
      }
    }
    setState(() => _fromCache = false);
    try {
      final useCase = ref.read(searchBooksProvider);
      final results = await useCase(kw, onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      });
      if (!mounted) return;
      // 写入缓存
      ref.read(searchResultCacheProvider).put(kw, results);
      setState(() {
        _rawResults = results;
      });
      // 记录搜索历史
      await ref.read(searchHistoryRepositoryProvider).record(kw);
      await _loadSuggestions();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 当前过滤+排序后的结果。
  List<SearchResult> get _results {
    var list = _rawResults;
    if (_filterSourceUrl != null) {
      list = list
          .where((r) => r.sources.any((s) => s.sourceUrl == _filterSourceUrl))
          .toList();
    }
    if (_filterKind != null) {
      list = list.where((r) => _normalizeKind(r.kind) == _filterKind).toList();
    }
    return sortSearchResults(list, _sort);
  }

  /// 提取所有出现过的书源（用于筛选条）。
  List<SearchSource> get _availableSources {
    final map = <String, SearchSource>{};
    for (final r in _rawResults) {
      for (final s in r.sources) {
        map.putIfAbsent(s.sourceUrl, () => s);
      }
    }
    return map.values.toList()
      ..sort((a, b) => a.sourceName.compareTo(b.sourceName));
  }

  /// 提取所有出现过的分类。
  List<String> get _availableKinds {
    final set = <String>{};
    for (final r in _rawResults) {
      final k = _normalizeKind(r.kind);
      if (k != null) set.add(k);
    }
    return set.toList()..sort();
  }

  String? _normalizeKind(String? kind) {
    if (kind == null || kind.trim().isEmpty) return null;
    // 取第一个分类词（按 ,，、 空白分割）
    final first = kind.split(RegExp(r'[,，、\s]+')).first;
    return first.trim().isEmpty ? null : first.trim();
  }

  Future<void> _clearHistory() async {
    await ref.read(searchHistoryRepositoryProvider).clear();
    await _loadSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜书'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            tooltip: '书源管理',
            onPressed: () => context.go('/book-sources'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '输入书名或作者',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_fromCache)
                            IconButton(
                              tooltip: '缓存中，点击强制刷新',
                              icon: const Icon(Icons.cached, size: 20),
                              onPressed: () =>
                                  _search(keyword: _lastKeyword, forceRefresh: true),
                            ),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _loading
                                ? null
                                : () => _search(),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          // 缓存徽章
          if (_fromCache && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _search(keyword: _lastKeyword, forceRefresh: true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '来自缓存 · 点击刷新',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ),
              ),
            ),
          // 搜索进度条
          if (_loading && _progress != null) _buildProgressBar(),
          if (_error != null) _buildErrorBanner(),
          // 排序 + 筛选条
          if (_rawResults.length > 1 && !_loading) _buildFilterBar(results.length),
          Expanded(
            child: _rawResults.isEmpty && !_loading
                ? _hasSearched
                    ? _buildNoResultGuide()
                    : _buildSuggestions()
                : results.isEmpty
                    ? Center(
                        child: Text('当前筛选下无结果',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) =>
                            SearchResultTile(result: results[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(int shownCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 排序下拉
          PopupMenuButton<SearchResultSort>(
            tooltip: '排序',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 14),
                  const SizedBox(width: 4),
                  Text(_sortLabel(_sort), style: const TextStyle(fontSize: 12)),
                  const Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: SearchResultSort.sourceCount,
                child: Text('按源数（多源优先）'),
              ),
              PopupMenuItem(
                value: SearchResultSort.wordCount,
                child: Text('按字数（长篇优先）'),
              ),
              PopupMenuItem(
                value: SearchResultSort.title,
                child: Text('按书名'),
              ),
            ],
          ),
          // 书源筛选
          if (_availableSources.length > 1)
            PopupMenuButton<String?>(
              tooltip: '筛选书源',
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _filterSourceUrl != null
                      ? Colors.teal.withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _filterSourceUrl == null
                          ? '全部源'
                          : _availableSources
                              .firstWhere((s) =>
                                  s.sourceUrl == _filterSourceUrl)
                              .sourceName,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 14),
                  ],
                ),
              ),
              onSelected: (v) => setState(() => _filterSourceUrl = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('全部源')),
                ..._availableSources.map((s) => PopupMenuItem(
                      value: s.sourceUrl,
                      child: Text(s.sourceName),
                    )),
              ],
            ),
          // 分类筛选
          if (_availableKinds.isNotEmpty)
            PopupMenuButton<String?>(
              tooltip: '筛选分类',
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _filterKind != null
                      ? Colors.teal.withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.label_outline, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _filterKind ?? '全分类',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 14),
                  ],
                ),
              ),
              onSelected: (v) => setState(() => _filterKind = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('全分类')),
                ..._availableKinds.map((k) => PopupMenuItem(
                      value: k,
                      child: Text(k),
                    )),
              ],
            ),
          // 计数
          Text(
            '$shownCount / ${_rawResults.length} 条',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          if (_filterSourceUrl != null || _filterKind != null)
            TextButton(
              onPressed: () => setState(() {
                _filterSourceUrl = null;
                _filterKind = null;
              }),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('清除筛选', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  String _sortLabel(SearchResultSort s) {
    switch (s) {
      case SearchResultSort.sourceCount:
        return '源数';
      case SearchResultSort.wordCount:
        return '字数';
      case SearchResultSort.title:
        return '书名';
    }
  }

  /// 搜索进度条：显示「3/6 源已返回 · 已找到 12 条」。
  Widget _buildProgressBar() {
    final p = _progress!;
    final ratio = p.total == 0 ? 0.0 : p.completed / p.total;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 4),
          Text(
            p.total == 0
                ? '无可用书源，请先导入'
                : '搜索中 ${p.completed}/${p.total} 源已返回 · 已找到 ${p.resultCount} 条',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  /// 初始空态：历史词 + 热门词。
  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_history.isNotEmpty) ...[
          _buildSectionHeader(
            title: '搜索历史',
            actionText: '清空',
            onAction: _clearHistory,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _history
                  .take(15)
                  .map((e) => _buildChip(
                        e.keyword,
                        onTap: () => _search(keyword: e.keyword),
                        onLongPress: () async {
                          await ref
                              .read(searchHistoryRepositoryProvider)
                              .delete(e.keyword);
                          await _loadSuggestions();
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildSectionHeader(title: '热门搜索'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hot
                .map((k) => _buildChip(k, onTap: () => _search(keyword: k)))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          if (actionText != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              child: Text(actionText, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  /// 搜索后无结果引导。
  Widget _buildNoResultGuide() {
    final p = _progress;
    final noSource = p != null && p.total == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              noSource ? Icons.library_books_outlined : Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              noSource ? '还没有可用书源' : '没有找到相关书籍',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              noSource
                  ? '导入书源后即可搜索全网小说'
                  : '换个关键词试试，或去书源管理添加更多源',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/book-sources'),
              icon: const Icon(Icons.library_books_outlined, size: 18),
              label: const Text('去书源管理'),
            ),
          ],
        ),
      ),
    );
  }
}
