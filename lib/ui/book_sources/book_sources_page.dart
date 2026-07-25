import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/hive_book_source_repository.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/ui/book_sources/book_source_import_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BookSourcesPage extends ConsumerStatefulWidget {
  const BookSourcesPage({super.key});

  @override
  ConsumerState<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends ConsumerState<BookSourcesPage> {
  late Future<List<BookSource>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(bookSourceRepositoryProvider);
    _future = repo is HiveBookSourceRepository
        ? repo.getAll()
        : repo.getEnabledSources();
  }

  Future<void> _openImport() async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => const BookSourceImportDialog(),
    );
    if (count != null && mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 $count 个书源')),
      );
    }
  }

  Future<void> _delete(BookSource source) async {
    await ref
        .read(bookSourceRepositoryProvider)
        .deleteByUrl(source.bookSourceUrl);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/search'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openImport,
            tooltip: '导入书源',
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
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('还没有书源'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openImport,
                    icon: const Icon(Icons.add),
                    label: const Text('导入书源'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = list[i];
              return ListTile(
                title: Text(s.bookSourceName),
                subtitle: Text(s.bookSourceUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.enabled ? Icons.check_circle : Icons.circle_outlined,
                      color: s.enabled ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(s),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
