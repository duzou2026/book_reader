import 'package:book_reader/data/models/search_result.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  const SearchResultTile({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cover = result.coverUrl;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => context.go('/book', extra: result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    cover,
                    width: 60,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverPlaceholder(),
                  ),
                )
              else
                _coverPlaceholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.bookName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.author,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    if (result.intro != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.intro!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final s in result.sources)
                          Chip(
                            label: Text(s.sourceName,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
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

  Widget _coverPlaceholder() {
    return Container(
      width: 60,
      height: 80,
      color: Colors.grey.shade200,
      child: const Icon(Icons.book, color: Colors.grey),
    );
  }
}
