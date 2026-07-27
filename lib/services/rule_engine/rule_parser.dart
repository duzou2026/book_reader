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

    // 含 {{$.path}} JSONPath 模板的 URL（如 /novels/api/book/{{$.book_id}}）
    // 这是 legado 的 URL 模板语法，需要做变量替换，而不是 XPath 解析。
    // 必须在 `/` → XPath 判定之前处理，否则会被误判为 XPath 而解析失败。
    if (RegExp(r'\{\{\$\.').hasMatch(trimmed)) {
      return RuleType.plain;
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
    // bare 属性名（href / src / text / title / content 等）：
    // legado 生态里 chapterUrl/bookUrl 常用裸属性名，需要走 LegadoRuleParser
    // 的「整个 rule 就是属性名」分支提取，而不是当字面量返回。
    // 判定：不含任何选择器语法字符的纯标识符。
    if (_isBareAttrName(trimmed)) {
      return RuleType.legado;
    }
    // 形如 ".foo > .bar" 或 "#foo .bar" 视为 CSS
    if (_looksLikeCss(trimmed)) {
      return RuleType.css;
    }

    return RuleType.plain;
  }

  /// 判断是否是 bare 属性名（如 `href` / `src` / `text` / `data-src`）。
  ///
  /// 用于 legado 书源里 chapterUrl/bookUrl/coverUrl 字段直接写属性名的场景。
  /// 判定标准：纯标识符（字母开头，含字母数字和 `-_`），不含 `.`/`@`/`/`/`$`/`#`/`>` 等
  /// 任何选择器/分隔符字符。
  static bool _isBareAttrName(String s) {
    if (s.isEmpty) return false;
    if (s.length > 30) return false; // 属性名不会这么长
    return RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$').hasMatch(s);
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
