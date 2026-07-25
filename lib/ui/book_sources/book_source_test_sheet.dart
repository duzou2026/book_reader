import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/domain/usecases/test_book_source.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书源测试面板：一键测试书源的全链路（搜索→详情→目录→正文）。
class BookSourceTestSheet extends ConsumerStatefulWidget {
  final BookSource source;
  const BookSourceTestSheet({super.key, required this.source});

  @override
  ConsumerState<BookSourceTestSheet> createState() => _BookSourceTestSheetState();
}

class _BookSourceTestSheetState extends ConsumerState<BookSourceTestSheet> {
  final _steps = <BookSourceTestStepResult>[];
  bool _running = false;
  bool _done = false;

  static const _stepIcons = {
    '搜索': Icons.search,
    '详情': Icons.info_outline,
    '目录': Icons.list,
    '正文': Icons.article_outlined,
  };

  Future<void> _run() async {
    setState(() {
      _steps.clear();
      _running = true;
      _done = false;
    });
    final useCase = ref.read(testBookSourceProvider);
    await useCase(widget.source, onStep: (step) {
      if (!mounted) return;
      setState(() {});
    });
    // useCase 返回后步骤已通过 onStep 实时上报；这里只是同步状态
    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
    });
  }

  @override
  void initState() {
    super.initState();
    // 打开即自动开始测试
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  Widget build(BuildContext context) {
    final allOk = _done && _steps.isNotEmpty && _steps.every((s) => s.ok);
    final hasFail = _steps.any((s) => !s.ok);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('书源测试',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      widget.source.bookSourceName,
                      style: TextStyle(
                          color: ThemeColors.mutedText(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_done)
                Chip(
                  label: Text(allOk ? '通过' : '存在问题',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: allOk
                      ? ThemeColors.successContainer(context)
                      : (hasFail ? Colors.orange.shade50 : ThemeColors.surfaceLevel1(context)),
                  side: BorderSide.none,
                  avatar: Icon(
                    allOk ? Icons.check_circle : Icons.warning_amber,
                    size: 18,
                    color: allOk
                        ? ThemeColors.successText(context)
                        : Colors.orange.shade700,
                  ),
                ),
            ],
          ),
          const Divider(height: 20),
          // 步骤列表
          ..._buildStepRows(),
          if (_steps.isEmpty && _running)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_done) ...[
            const SizedBox(height: 12),
            Text(
              _summarize(),
              style: TextStyle(
                color: allOk ? ThemeColors.successText(context) : ThemeColors.mutedText(context),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 操作按钮
          Row(
            children: [
              if (_done)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? null : _run,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新测试'),
                  ),
                ),
              if (_done) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _running
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStepRows() {
    final predefined = ['搜索', '详情', '目录', '正文'];
    final rows = <Widget>[];
    for (final name in predefined) {
      final step = _steps.where((s) => s.name == name).toList();
      if (step.isEmpty) {
        // 未执行的步骤：灰色占位
        if (_running && _steps.length < predefined.indexOf(name) + 1) {
          rows.add(_buildStepRow(
            name: name,
            state: _StepState.pending,
          ));
        }
        continue;
      }
      rows.add(_buildStepRow(
        name: name,
        state: step.last.ok ? _StepState.ok : _StepState.fail,
        message: step.last.message,
        elapsedMs: step.last.elapsedMs,
      ));
    }
    return rows;
  }

  Widget _buildStepRow({
    required String name,
    required _StepState state,
    String? message,
    int? elapsedMs,
  }) {
    final icon = _stepIcons[name] ?? Icons.circle_outlined;
    final (color, statusText, statusIcon) = switch (state) {
      _StepState.pending => (
          ThemeColors.mutedText(context),
          '等待中',
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _StepState.running => (
          Theme.of(context).colorScheme.primary,
          '测试中',
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      _StepState.ok => (
          ThemeColors.successText(context),
          elapsedMs == null ? '通过' : '${elapsedMs}ms',
          Icon(Icons.check_circle, size: 16, color: ThemeColors.successText(context)),
        ),
      _StepState.fail => (
          ThemeColors.errorText(context),
          elapsedMs == null ? '失败' : '失败 · ${elapsedMs}ms',
          Icon(Icons.cancel, size: 16, color: ThemeColors.errorText(context)),
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          if (message != null)
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: ThemeColors.mutedText(context), fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          Text(statusText, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 6),
          statusIcon,
        ],
      ),
    );
  }

  String _summarize() {
    if (_steps.isEmpty) return '';
    final okCount = _steps.where((s) => s.ok).length;
    final total = _steps.length;
    final totalMs = _steps.fold<int>(0, (s, e) => s + e.elapsedMs);
    if (okCount == total) {
      return '全部通过 · 共 $total 步 · 耗时 ${totalMs}ms';
    }
    return '$okCount/$total 步通过 · 失败步骤：${_steps.where((s) => !s.ok).map((s) => s.name).join('、')}';
  }
}

enum _StepState { pending, running, ok, fail }
