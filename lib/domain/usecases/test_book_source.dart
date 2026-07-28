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

  /// 步骤状态：ok=通过, skip=跳过(如搜索无结果时后续步骤), fail=失败。
  final TestStepStatus status;

  const BookSourceTestStepResult({
    required this.name,
    required this.ok,
    required this.elapsedMs,
    required this.message,
    this.status = TestStepStatus.ok,
  });
}

/// 测试步骤状态。
enum TestStepStatus {
  /// 通过。
  ok,
  /// 跳过（前置步骤无结果，非失败）。
  skip,
  /// 失败（异常/超时）。
  fail,
}

/// 书源测试完整结果。
class BookSourceTestResult {
  final List<BookSourceTestStepResult> steps;

  const BookSourceTestResult({required this.steps});

  /// 全部通过。
  bool get allOk => steps.isNotEmpty && steps.every((s) => s.ok);

  /// 是否有失败步骤（异常/超时，不含跳过）。
  bool get hasFail => steps.any((s) => s.status == TestStepStatus.fail);

  /// 是否有跳过步骤（前置无结果导致后续跳过，非失败）。
  bool get hasSkip => steps.any((s) => s.status == TestStepStatus.skip);

  /// 综合状态：allOk=通过, hasFail=存在问题, hasSkip=部分通过。
  TestOverallStatus get overallStatus {
    if (steps.isEmpty) return TestOverallStatus.fail;
    if (allOk) return TestOverallStatus.ok;
    if (hasFail) return TestOverallStatus.fail;
    return TestOverallStatus.partial;
  }

  int get totalElapsedMs =>
      steps.fold(0, (sum, s) => sum + s.elapsedMs);
}

/// 测试综合状态。
enum TestOverallStatus {
  /// 全部通过。
  ok,
  /// 部分通过（有跳过，无失败）。
  partial,
  /// 存在问题（有失败）。
  fail,
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

  /// 单步超时。15 秒，兼顾慢站点和网络抖动。
  final Duration stepTimeout;

  TestBookSource({
    required this.searcher,
    required this.bookInfoFetcher,
    required this.tocFetcher,
    required this.contentFetcher,
    this.testKeyword = '斗破苍穹',
    this.stepTimeout = const Duration(seconds: 15),
  });

  /// 执行测试。[onStep] 在每步完成时回调，用于 UI 实时展示。
  Future<BookSourceTestResult> call(
    BookSource source, {
    void Function(BookSourceTestStepResult step)? onStep,
  }) async {
    final steps = <BookSourceTestStepResult>[];

    // 步骤 1：搜索
    // 搜索无结果不算失败（书源可能就是没收录这本书），标记为 skip 并终止后续步骤。
    final searchResult = await _runStep(
      name: '搜索',
      steps: steps,
      onStep: onStep,
      action: () async {
        final list = await searcher
            .search(testKeyword, source)
            .timeout(stepTimeout);
        if (list.isEmpty) {
          // 搜索无结果：返回 null 触发 skip 路径（非异常）
          return null;
        }
        return list.first;
      },
      summarize: (r) =>
          '找到《${r.bookName}》- ${r.author}（共 ${r.sources.length} 源）',
      emptyMessage: '未找到「$testKeyword」相关书籍',
    );
    if (searchResult == null) {
      // 搜索无结果或失败，后续步骤无法执行
      // 若搜索步骤本身标记为 skip（非 fail），后续步骤也标记 skip
      final searchStep = steps.last;
      if (searchStep.status == TestStepStatus.skip) {
        for (final name in ['详情', '目录', '正文']) {
          final step = BookSourceTestStepResult(
            name: name,
            ok: false,
            elapsedMs: 0,
            message: '前置步骤无结果，已跳过',
            status: TestStepStatus.skip,
          );
          steps.add(step);
          onStep?.call(step);
        }
      }
      return BookSourceTestResult(steps: steps);
    }

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
      emptyMessage: '目录为空',
    );
    if (tocResult == null || tocResult.isEmpty) {
      // 目录为空时，正文步骤标记 skip
      final step = BookSourceTestStepResult(
        name: '正文',
        ok: false,
        elapsedMs: 0,
        message: '目录为空，已跳过',
        status: TestStepStatus.skip,
      );
      steps.add(step);
      onStep?.call(step);
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
  ///
  /// [emptyMessage] 非 null 时：action 返回 null 表示"无结果"（skip），
  /// 而非异常失败。用于搜索结果为空、目录为空等正常业务场景。
  Future<T?> _runStep<T>({
    required String name,
    required List<BookSourceTestStepResult> steps,
    required void Function(BookSourceTestStepResult)? onStep,
    required Future<T?> Function() action,
    required String Function(T) summarize,
    String? emptyMessage,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await action();
      sw.stop();
      // 结果为 null 且指定了 emptyMessage → 标记为 skip（非失败）
      if (result == null && emptyMessage != null) {
        final step = BookSourceTestStepResult(
          name: name,
          ok: false,
          elapsedMs: sw.elapsedMilliseconds,
          message: emptyMessage,
          status: TestStepStatus.skip,
        );
        steps.add(step);
        onStep?.call(step);
        return null;
      }
      final step = BookSourceTestStepResult(
        name: name,
        ok: true,
        elapsedMs: sw.elapsedMilliseconds,
        message: summarize(result as T),
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
        status: TestStepStatus.fail,
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
