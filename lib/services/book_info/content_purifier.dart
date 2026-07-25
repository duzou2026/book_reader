/// 章节正文净化器。
///
/// 解析 legado 风格的 `replaceRegex` 字段并应用到正文，支持：
///   - 多条规则用 `\n` 或 `||` 分隔（忽略空规则）
///   - `regex` → 替换为空字符串
///   - `regex##replacement` → 替换为 replacement
///   - 替换串中可引用捕获组：`$1`、`$2`、`$<name>`、`${1}`
///   - 前缀 flag：`(?i)pattern`、`(?im)pattern` 等 → 转为 RegExp 选项
///
/// 注意：Dart RegExp 不支持 ECMAScript 风格的内联 `(?i)` 标志，
/// 因此本实现会解析规则开头的 `(?i)`、`(?m)`、`(?s)`、`(?x)` 前缀
/// 并转为 [RegExp.caseSensitive] / [RegExp.multiLine] / [RegExp.dotAll]
/// 构造参数。
class ContentPurifier {
  ContentPurifier._();

  /// 将 [content] 应用 [replaceRegex] 规则后返回净化结果。
  ///
  /// 解析失败的规则会被跳过（不抛错），保证部分规则失效不影响整体。
  static String purify(String content, String replaceRegex) {
    if (replaceRegex.isEmpty) return content;
    final rules = _splitRules(replaceRegex);
    var result = content;
    for (final raw in rules) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final parsed = _parseRule(trimmed);
      if (parsed == null) continue;
      try {
        final compiled = _compilePattern(parsed.pattern);
        result = _applyOne(result, compiled, parsed.replacement);
      } catch (_) {
        // 无效正则跳过
      }
    }
    return result;
  }

  /// 校验 [replaceRegex] 字段，返回 (ruleCount, errorCount)。
  ///
  /// 用于 UI 中实时反馈规则有效性。
  static PurifyValidateResult validate(String replaceRegex) {
    if (replaceRegex.trim().isEmpty) {
      return const PurifyValidateResult(ruleCount: 0, errorCount: 0, errors: []);
    }
    final rules = _splitRules(replaceRegex);
    var ruleCount = 0;
    var errorCount = 0;
    final errors = <String>[];
    for (final raw in rules) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      ruleCount++;
      final parsed = _parseRule(trimmed);
      if (parsed == null) {
        errorCount++;
        errors.add('格式错误：$trimmed');
        continue;
      }
      try {
        _compilePattern(parsed.pattern);
      } catch (e) {
        errorCount++;
        errors.add('正则无效：${parsed.pattern}（$e）');
      }
    }
    return PurifyValidateResult(
      ruleCount: ruleCount,
      errorCount: errorCount,
      errors: errors,
    );
  }

  /// 拆分多规则：
  /// - 实际换行符（`\n` / `\r\n` / `\r`）作为分隔符
  /// - 字面 `||` 作为分隔符
  /// - 字面 `\n`（反斜杠+n 两字符）也作为分隔符（便于 UI 单行输入）
  static List<String> _splitRules(String replaceRegex) {
    final normalized = replaceRegex
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\\n', '\n');
    return normalized.split(RegExp(r'\n|\|\|'));
  }

  /// 解析单条规则：`regex##replacement` 或 `regex`。
  static _ParsedRule? _parseRule(String rule) {
    // 仅在首个 `##` 处拆分，避免 replacement 中包含 `##` 字符串被错误拆分
    final idx = rule.indexOf('##');
    if (idx < 0) {
      final pattern = rule.trim();
      if (pattern.isEmpty) return null;
      return _ParsedRule(pattern: pattern, replacement: '');
    }
    final pattern = rule.substring(0, idx).trim();
    final replacement = rule.substring(idx + 2);
    if (pattern.isEmpty) return null;
    return _ParsedRule(pattern: pattern, replacement: replacement);
  }

  /// 解析并编译正则：识别前缀 `(?flags)` 转为 [RegExp] 构造参数。
  ///
  /// 支持的 flag 字符：
  ///   - `i` → caseSensitive: false
  ///   - `m` → multiLine: true
  ///   - `s` → dotAll: true
  ///   - `x` → 忽略（Dart 不支持 verbose 模式，直接移除）
  static RegExp _compilePattern(String pattern) {
    var p = pattern;
    var caseSensitive = true;
    var multiLine = false;
    var dotAll = false;

    // 反复剥离开头的 (?flags) 或 (?flags:sub) 形式
    final flagPrefixRe = RegExp(r'^\(\?([imsx]+)\)');
    while (true) {
      final m = flagPrefixRe.firstMatch(p);
      if (m == null) break;
      final flags = m.group(1)!;
      if (flags.contains('i')) caseSensitive = false;
      if (flags.contains('m')) multiLine = true;
      if (flags.contains('s')) dotAll = true;
      // x：Dart 不支持，直接丢弃
      p = p.substring(m.end);
    }

    return RegExp(
      p,
      caseSensitive: caseSensitive,
      multiLine: multiLine,
      dotAll: dotAll,
    );
  }

  /// 应用单条规则到 [input]：使用 `replaceAllMapped` 支持捕获组引用。
  static String _applyOne(
      String input, RegExp pattern, String replacement) {
    if (replacement.isEmpty) {
      return input.replaceAll(pattern, '');
    }
    // 检测是否含捕获组引用
    final groupRef = RegExp(r'\$(\d+|\{[^}]+\}|<[^>]+>)');
    if (!groupRef.hasMatch(replacement)) {
      return input.replaceAll(pattern, replacement);
    }
    return input.replaceAllMapped(pattern, (m) {
      return _expandReplacement(replacement, m as RegExpMatch);
    });
  }

  /// 展开 replacement 中的 `$1`、`$2`、`${1}`、`$<name>` 等引用。
  static String _expandReplacement(String replacement, RegExpMatch m) {
    final buf = StringBuffer();
    final refPattern = RegExp(r'\$(\d+|\{(\d+)\}|<([^>]+)>)');
    var lastEnd = 0;
    for (final ref in refPattern.allMatches(replacement)) {
      buf.write(replacement.substring(lastEnd, ref.start));
      final groupIdx = ref.group(1)!;
      String? value;
      if (groupIdx.startsWith('{')) {
        // ${1} 形式
        final n = int.tryParse(ref.group(2)!);
        if (n != null) value = _safeGroup(m, n);
      } else if (groupIdx.startsWith('<')) {
        // $<name> 形式
        final name = ref.group(3)!;
        value = m.namedGroup(name);
      } else {
        // $1 形式
        final n = int.tryParse(groupIdx);
        if (n != null) value = _safeGroup(m, n);
      }
      buf.write(value ?? '');
      lastEnd = ref.end;
    }
    buf.write(replacement.substring(lastEnd));
    return buf.toString();
  }

  /// 安全获取捕获组：越界返回 null。
  static String? _safeGroup(RegExpMatch m, int n) {
    try {
      return m.group(n);
    } catch (_) {
      return null;
    }
  }
}

class _ParsedRule {
  final String pattern;
  final String replacement;
  const _ParsedRule({required this.pattern, required this.replacement});
}

/// 校验结果。
class PurifyValidateResult {
  final int ruleCount;
  final int errorCount;
  final List<String> errors;
  const PurifyValidateResult({
    required this.ruleCount,
    required this.errorCount,
    required this.errors,
  });

  bool get isValid => errorCount == 0;
}
