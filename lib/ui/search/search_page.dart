import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/data/search_history_repository.dart';
import 'package:book_reader/services/search/search_aggregator.dart';
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
  List<SearchResult> _results = const [];
  bool _loading = false;
  String? _error;

  /// 搜索进度（null 表示未在搜索或无源）。
  SearchProgress? _progress;

  /// 是否已展示过结果（区分「初始空态」和「搜索后无结果」）。
  bool _hasSearched = false;

  /// 搜索历史。
  List<SearchHistoryEntry> _history = const [];

  /// 热门词。
  List<String> _hot = const [];

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

  Future<void> _search({String? keyword}) async {
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
    });
    try {
      final useCase = ref.read(searchBooksProvider);
      final results = await useCase(kw, onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _results = results);
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

  Future<void> _clearHistory() async {
    await ref.read(searchHistoryRepositoryProvider).clear();
    await _loadSuggestions();
  }

  @override
  Widget build(BuildContext context) {
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
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _loading ? null : () => _search(),
                      ),
              ),
            ),
          ),
          // 搜索进度条
          if (_loading && _progress != null) _buildProgressBar(),
          if (_error != null) _buildErrorBanner(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? _hasSearched
                    ? _buildNoResultGuide()
                    : _buildSuggestions()
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) =>
                        SearchResultTile(result: _results[i]),
                  ),
          ),
        ],
      ),
    );
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
