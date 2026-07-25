/// 规则类型识别器。
///
/// legado 书源规则支持多种前缀语法来指定解析方式：
///   - `@css:` / `css:`     → CSS 选择器
///   - `@json:` / `json:`   → JSONPath
///   - `@xpath:` / `xpath:` → XPath
///   - `@regex:` / `regex:` → 正则表达式
///   - `@js:` / `js:` / `<js>...</js>` → JavaScript
///
/// 没有前缀时，根据内容形态自动判定：以 `$` 开头视为 JSONPath，
/// 否则按纯文本字面量返回。
enum RuleType { css, json, xpath, regex, js, plain }

class RuleParser {
  RuleType detect(String rule) {
    final trimmed = rule.trim();
    if (trimmed.isEmpty) return RuleType.plain;

    if (trimmed.startsWith('@css:') || trimmed.startsWith('css:')) {
      return RuleType.css;
    }
    if (trimmed.startsWith('@json:') || trimmed.startsWith('json:')) {
      return RuleType.json;
    }
    if (trimmed.startsWith('@xpath:') || trimmed.startsWith('xpath:')) {
      return RuleType.xpath;
    }
    if (trimmed.startsWith('@regex:') || trimmed.startsWith('regex:')) {
      return RuleType.regex;
    }
    if (trimmed.startsWith('@js:') ||
        trimmed.startsWith('js:') ||
        trimmed.startsWith('<js>')) {
      return RuleType.js;
    }

    // 无前缀时的启发式判定
    // 以 $ 开头（如 $.data.name 或 $..name）视为 JSONPath
    if (trimmed.startsWith(r'$')) {
      return RuleType.json;
    }
    // 形如 ".foo > .bar" 或 ".foo@text" 视为 CSS
    if (_looksLikeCss(trimmed)) {
      return RuleType.css;
    }

    return RuleType.plain;
  }

  /// 简单启发式：含 CSS 选择器特征字符（. # > + ~）且不含空格分隔的命令时，视为 CSS。
  bool _looksLikeCss(String s) {
    final cssHints = ['.', '#', '>', ' + ', ' ~ '];
    var hits = 0;
    for (final h in cssHints) {
      if (s.contains(h)) hits++;
    }
    // 至少有一个 CSS 特征字符
    return hits >= 1;
  }
}
