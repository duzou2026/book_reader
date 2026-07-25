import 'package:book_reader/app/providers.dart';
import 'package:book_reader/services/book_source/book_source_importer.dart';
import 'package:book_reader/services/book_source/book_source_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书源导入对话框：用户粘贴 legado 书源 JSON 文本后导入。
///
/// 返回值：导入成功条数（int），用户取消返回 null。
class BookSourceImportDialog extends ConsumerStatefulWidget {
  const BookSourceImportDialog({super.key});

  @override
  ConsumerState<BookSourceImportDialog> createState() =>
      _BookSourceImportDialogState();
}

class _BookSourceImportDialogState extends ConsumerState<BookSourceImportDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '请粘贴书源 JSON');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = BookSourceImporter().parse(text, throwOnInvalid: false);
      final repo = ref.read(bookSourceRepositoryProvider);
      for (final s in sources) {
        await repo.upsert(s);
      }
      if (!mounted) return;
      Navigator.of(context).pop(sources.length);
    } on BookSourceValidationException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入书源'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '粘贴 legado 书源 JSON（单个对象或数组）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '[\n  { "bookSourceName": "...", "bookSourceUrl": "..." }\n]',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading ? null : _import,
          child: Text(_loading ? '导入中...' : '导入'),
        ),
      ],
    );
  }
}
