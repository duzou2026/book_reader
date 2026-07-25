import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/book_info_fetcher.dart';
import 'package:book_reader/services/book_info/content_fetcher.dart';
import 'package:book_reader/services/book_info/toc_fetcher.dart';
import 'package:book_reader/services/search/single_source_searcher.dart';

/// 单个测试步骤的结果。
class BookSourceTestStepResult {
  /// 步骤名：搜索 / 详情 / 目录 / 正文。
  final String name;

  /// 是否通过。
  final bool ok;

  /// 耗时（毫秒）。
  final int elapsedMs;

  /// 提示信息（成功时为摘要，失败时为错误原因）。
  final String message;

  const BookSourceTestStepResult({
    required this.name,
    required this.ok,
    required this.elapsedMs,
    required this.message,
  });
}

/// 书源测试完整结果。
class BookSourceTestResult {
  final List<BookSourceTestStepResult> steps;

  const BookSourceTestResult({required this.steps});

  bool get allOk => steps.isNotEmpty && steps.every((s) => s.ok);

  int get totalElapsedMs =>
      steps.fold(0, (sum, s) => sum + s.elapsedMs);
}

/// 书源测试用例：对一个书源执行全链路测试。
///
/// 流程：搜索「测试」关键词 → 取第一条结果 → 拉详情 → 拉目录 → 拉第一章正文。
/// 任意一步失败即终止后续，返回已完成的步骤结果。
class TestBookSource {
  final SingleSourceSearcher searcher;
  final BookInfoFetcher bookInfoFetcher;
  final TocFetcher tocFetcher;
  final ContentFetcher contentFetcher;

  /// 测试用关键词。默认「斗破苍穹」（中文小说站点覆盖率较高）。
  final String testKeyword;

  /// 单步超时。
  final Duration stepTimeout;

  TestBookSource({
    required this.searcher,
    required this.bookInfoFetcher,
    required this.tocFetcher,
    required this.contentFetcher,
    this.testKeyword = '斗破苍穹',
    this.stepTimeout = const Duration(seconds: 10),
  });

  /// 执行测试。[onStep] 在每步完成时回调，用于 UI 实时展示。
  Future<BookSourceTestResult> call(
    BookSource source, {
    void Function(BookSourceTestStepResult step)? onStep,
  }) async {
    final steps = <BookSourceTestStepResult>[];

    // 步骤 1：搜索
    final searchResult = await _runStep(
      name: '搜索',
      steps: steps,
      onStep: onStep,
      action: () async {
        final list = await searcher
            .search(testKeyword, source)
            .timeout(stepTimeout);
        if (list.isEmpty) {
          throw Exception('搜索结果为空');
        }
        return list.first;
      },
      summarize: (r) =>
          '找到《${r.bookName}》- ${r.author}（共 ${r.sources.length} 源）',
    );
    if (searchResult == null) return BookSourceTestResult(steps: steps);

    // 步骤 2：详情
    final infoResult = await _runStep<BookInfo>(
      name: '详情',
      steps: steps,
      onStep: onStep,
      action: () async {
        final src = searchResult.sources.first;
        final info = await bookInfoFetcher
            .fetch(src.bookUrl, source)
            .timeout(stepTimeout);
        // 兜底：用搜索结果补全
        return info.copyWith(
          name: info.name ?? searchResult.bookName,
          author: info.author ?? searchResult.author,
          url: info.url.isNotEmpty ? info.url : src.bookUrl,
          sourceName: source.bookSourceName,
          sourceUrl: source.bookSourceUrl,
        );
      },
      summarize: (i) =>
          '《${i.name ?? '?'}》· ${i.author ?? '?'} · ${i.intro?.length ?? 0} 字简介',
    );
    if (infoResult == null) return BookSourceTestResult(steps: steps);

    // 步骤 3：目录
    final tocResult = await _runStep<List<Chapter>>(
      name: '目录',
      steps: steps,
      onStep: onStep,
      action: () async {
        final tocUrl = infoResult.tocUrl ?? infoResult.url;
        return tocFetcher.fetch(tocUrl, source).timeout(stepTimeout);
      },
      summarize: (list) => '共 ${list.length} 章',
    );
    if (tocResult == null || tocResult.isEmpty) {
      return BookSourceTestResult(steps: steps);
    }

    // 步骤 4：正文（取第一章）
    await _runStep<String>(
      name: '正文',
      steps: steps,
      onStep: onStep,
      action: () async {
        final firstChapter = tocResult.firstWhere(
          (c) => !c.isVolume,
          orElse: () => tocResult.first,
        );
        final content = await contentFetcher
            .fetch(firstChapter.url, source)
            .timeout(stepTimeout);
        if (content.trim().isEmpty) {
          throw Exception('正文为空');
        }
        return content;
      },
      summarize: (c) => '${c.length} 字',
    );

    return BookSourceTestResult(steps: steps);
  }

  /// 执行单个步骤，捕获异常并记录耗时。
  Future<T?> _runStep<T>({
    required String name,
    required List<BookSourceTestStepResult> steps,
    required void Function(BookSourceTestStepResult)? onStep,
    required Future<T> Function() action,
    required String Function(T) summarize,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await action();
      sw.stop();
      final step = BookSourceTestStepResult(
        name: name,
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        message: summarize(result),
      );
      steps.add(step);
      onStep?.call(step);
      return result;
    } catch (e) {
      sw.stop();
      final step = BookSourceTestStepResult(
        name: name,
        ok: false,
        elapsedMs: sw.elapsedMilliseconds,
        message: _formatError(e),
      );
      steps.add(step);
      onStep?.call(step);
      return null;
    }
  }

  String _formatError(Object e) {
    final s = e.toString();
    // 去掉 Exception/TimeoutException 前缀，保留核心信息
    if (s.startsWith('Exception: ')) return s.substring(11);
    if (s.startsWith('TimeoutException')) return '超时';
    return s;
  }
}
