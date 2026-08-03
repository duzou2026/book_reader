import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/models/search_result.dart';
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
/// 流程：搜索（多关键词备选）→ 取第一条结果 → 拉详情 → 拉目录 → 拉第一章正文。
/// 任意一步失败即终止后续，返回已完成的步骤结果。
///
/// 设计要点（修复"书源测试也有问题"）：
///   - 搜索步骤用**多关键词备选**（斗破苍穹/三体/雪中悍刀行），
///     单一关键词未收录不代表源不可用，避免大量误判为"搜索无结果→全跳过"
///   - 搜索步骤明确区分「源本身不可用」(fail) 与「关键词未收录」(skip)
///   - 正文步骤除判空外，还做最小长度与反爬验证页检测，
///     避免"返回了验证页/JS 挑战页"被误判为"正文获取成功"
class TestBookSource {
  final SingleSourceSearcher searcher;
  final BookInfoFetcher bookInfoFetcher;
  final TocFetcher tocFetcher;
  final ContentFetcher contentFetcher;

  /// 测试用关键词（按序尝试，第一个出结果的为准）。
  /// 覆盖玄幻/科幻/武侠不同题材，提高单源命中率。
  final List<String> testKeywords;

  /// 单步超时。15 秒，兼顾慢站点和网络抖动。
  final Duration stepTimeout;

  TestBookSource({
    required this.searcher,
    required this.bookInfoFetcher,
    required this.tocFetcher,
    required this.contentFetcher,
    this.testKeywords = const ['斗破苍穹', '三体', '雪中悍刀行'],
    this.stepTimeout = const Duration(seconds: 15),
  });

  /// 执行测试。[onStep] 在每步完成时回调，用于 UI 实时展示。
  Future<BookSourceTestResult> call(
    BookSource source, {
    void Function(BookSourceTestStepResult step)? onStep,
  }) async {
    final steps = <BookSourceTestStepResult>[];

    // 步骤 1：搜索（多关键词备选，任一命中即通过）
    final searchResult = await _runSearchStep(source, steps, onStep);
    if (searchResult == null) {
      // 搜索步骤已记录（skip 或 fail），后续步骤统一标记 skip
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

    // 步骤 4：正文（取第一章），除判空外还做最小长度与反爬页检测
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
        final trimmed = content.trim();
        if (trimmed.isEmpty) {
          throw Exception('正文为空');
        }
        // 反爬验证页/JS 挑战页误判为"正文成功"是测试不准的重灾区，
        // 长度太短（<50 字）的内容基本可以判定为无效（验证提示/错误页）。
        if (trimmed.length < 50) {
          throw Exception('正文过短（${trimmed.length} 字），疑似验证页或错误页');
        }
        return content;
      },
      summarize: (c) => '${c.length} 字',
    );

    return BookSourceTestResult(steps: steps);
  }

  /// 搜索步骤：多关键词备选，第一个有结果的关键词生效。
  ///
  /// 返回命中的第一条 [SearchResult]；全部关键词都无结果返回 null。
  /// 区分两种失败：
  ///   - 所有关键词都正常返回但为空 → skip（源可用但没收录这些书）
  ///   - 全部关键词都抛异常/超时 → fail（源本身不可用）
  Future<SearchResult?> _runSearchStep(
    BookSource source,
    List<BookSourceTestStepResult> steps,
    void Function(BookSourceTestStepResult)? onStep,
  ) async {
    final sw = Stopwatch()..start();
    var sawException = false;
    var sawEmpty = false;
    Object? lastError;

    for (final kw in testKeywords) {
      try {
        final list = await searcher.search(kw, source).timeout(stepTimeout);
        if (list.isNotEmpty) {
          sw.stop();
          final r = list.first;
          final step = BookSourceTestStepResult(
            name: '搜索',
            ok: true,
            elapsedMs: sw.elapsedMilliseconds,
            message: '找到《${r.bookName}》- ${r.author}（关键词「$kw」）',
            status: TestStepStatus.ok,
          );
          steps.add(step);
          onStep?.call(step);
          return r;
        }
        sawEmpty = true;
      } catch (e) {
        sawException = true;
        lastError = e;
        // 当前关键词失败，尝试下一个
      }
    }
    sw.stop();

    // 全部关键词都无结果：区分"源可用但没收录"(skip) 与"源不可用"(fail)
    // 判定：只要有一个关键词正常返回空（sawEmpty）就视为源可用 → skip；
    // 全部都是异常（sawException 且无 empty）→ fail。
    final isSourceDead = sawException && !sawEmpty;
    final step = BookSourceTestStepResult(
      name: '搜索',
      ok: false,
      elapsedMs: sw.elapsedMilliseconds,
      message: isSourceDead
          ? '请求失败：${_formatError(lastError ?? '未知错误')}'
          : '未找到「${testKeywords.join(' / ')}」相关书籍',
      status: isSourceDead ? TestStepStatus.fail : TestStepStatus.skip,
    );
    steps.add(step);
    onStep?.call(step);
    return null;
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
