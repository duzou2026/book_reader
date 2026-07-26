import 'legado_rule_parser.dart';

/// 规则类型识别器。
///
/// legado 书源规则支持多种前缀语法来指定解析方式：
///   - `@css:` / `css:`     → CSS 选择器
///   - `@json:` / `json:`   → JSONPath
///   - `@xpath:` / `xpath:` → XPath
///   - `@regex:` / `regex:` → 正则表达式
///   - `@js:` / `js:` / `<js>...</js>` → JavaScript
///   - 无前缀但以 `class.` / `tag.` / `id.` 开头 → legado 旧式语法
///   - 无前缀但以 `//` 开头 → XPath
///
/// 没有前缀时，根据内容形态自动判定。
enum RuleType { css, json, xpath, regex, js, plain, legado }

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
    // 以 // 开头（如 //meta[@property='og:novel:author']/@content）视为 XPath
    if (trimmed.startsWith('//') || trimmed.startsWith('/')) {
      return RuleType.xpath;
    }
    // legado 旧式语法：以 class. / tag. / id. / children. 开头，
    // 或含 @ 步骤分隔符 / !N 索引语法（如 #author@tbody@tr!0）
    if (LegadoRuleParser.isLegadoRule(trimmed)) {
      return RuleType.legado;
    }
    // 形如 ".foo > .bar" 或 "#foo .bar" 视为 CSS
    if (_looksLikeCss(trimmed)) {
      return RuleType.css;
    }

    return RuleType.plain;
  }

  /// 简单启发式：判断字符串是否符合 CSS 选择器形态。
  ///
  /// CSS 选择器的关键特征：
  ///   - 含 `.` / `#` / `>` / `+` / `~` 等组合符
  ///   - **不含 `@`**（legado 用 @ 作步骤分隔符，CSS 选择器不会用到）
  ///   - **不含 `!N` 末尾索引**（legado 的索引语法）
  bool _looksLikeCss(String s) {
    // 含 @ → legado 步骤分隔符，不是 CSS
    if (s.contains('@')) return false;
    // 末尾的 !N → legado 索引语法
    if (RegExp(r'!\d+$').hasMatch(s)) return false;
    final cssHints = ['.', '#', '>', ' + ', ' ~ '];
    for (final h in cssHints) {
      if (s.contains(h)) return true;
    }
    return false;
  }
}
