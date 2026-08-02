import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/search_result.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchResultTile extends ConsumerWidget {
  final SearchResult result;
  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = result.coverUrl;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => context.push('/book', extra: result),
        onLongPress: () => _addToShelf(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    cover,
                    width: 56,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverPlaceholder(context),
                  ),
                )
              else
                _coverPlaceholder(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.bookName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.author,
                      style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.intro != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        result.intro!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final s in result.sources)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.sourceName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToShelf(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(bookshelfRepositoryProvider);
    final s = result.sources.first;
    final entry = BookshelfEntry(
      id: '${result.bookName}|${result.author}'.hashCode.toString(),
      bookName: result.bookName,
      author: result.author,
      coverUrl: result.coverUrl,
      intro: result.intro,
      kind: result.kind,
      wordCount: result.wordCount,
      lastChapter: result.lastChapter,
      sourceName: s.sourceName,
      sourceUrl: s.sourceUrl,
      bookUrl: s.bookUrl,
      addedAt: DateTime.now().millisecondsSinceEpoch,
      lastReadAt: DateTime.now().millisecondsSinceEpoch,
    );
    final existed = await repo.contains(entry.id);
    if (existed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已在书架中'), duration: Duration(seconds: 1)),
      );
      return;
    }
    await repo.upsert(entry);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已加入书架：${result.bookName}'),
          duration: const Duration(seconds: 1),
          action: SnackBarAction(
            label: '查看',
            onPressed: () {
              while (context.canPop()) context.pop();
              context.go('/shelf');
            },
          ),
        ),
      );
    }
  }

  Widget _coverPlaceholder(BuildContext context) {
    return Container(
      width: 60,
      height: 80,
      color: ThemeColors.surfaceLevel2(context),
      child: Icon(Icons.book, color: ThemeColors.mutedText(context)),
    );
  }
}
