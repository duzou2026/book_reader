/// 正则解析器。
///
/// legado 书源的 regex 规则语法形如：
///   `regex:<pattern>` 或 `@regex:<pattern>`
///
/// - 若 pattern 中含捕获组 `(...)`，返回第一个捕获组的内容。
/// - 否则返回整个匹配。
class RegexParser {
  String? queryFirst(String input, String rule) {
    final pattern = _stripPrefix(rule);
    final m = RegExp(pattern, dotAll: true).firstMatch(input);
    if (m == null) return null;
    if (m.groupCount >= 1) {
      return m.group(1);
    }
    return m.group(0);
  }

  List<String> queryList(String input, String rule) {
    final pattern = _stripPrefix(rule);
    return RegExp(pattern, dotAll: true)
        .allMatches(input)
        .map((m) {
          if (m.groupCount >= 1) {
            return m.group(1) ?? '';
          }
          return m.group(0) ?? '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _stripPrefix(String rule) {
    var p = rule.trim();
    if (p.startsWith('@regex:')) return p.substring('@regex:'.length);
    if (p.startsWith('regex:')) return p.substring('regex:'.length);
    return p;
  }
}
