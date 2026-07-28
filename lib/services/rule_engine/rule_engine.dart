import 'package:html/dom.dart';

import 'css_selector_parser.dart';
import 'js_executor.dart';
import 'jsonpath_parser.dart';
import 'legado_rule_parser.dart';
import 'regex_parser.dart';
import 'rule_parser.dart';
import 'xpath_parser.dart';

/// 规则引擎统一入口。
///
/// 调用方传入书源规则字符串和抓取到的原始文本（HTML/JSON），
/// 引擎根据规则前缀自动分发到对应解析器并返回字符串结果。
///
/// 设计上保持无状态、可同步调用，便于在 Isolate 中并发跑。
class RuleEngine {
  final RuleParser _parser;
  final CssSelectorParser _css;
  final JsonPathParser _jsonPath;
  final RegexParser _regex;
  final JsExecutor _js;
  final LegadoRuleParser _legado;
  final XpathParser _xpath;

  RuleEngine({
    RuleParser? parser,
    CssSelectorParser? css,
    JsonPathParser? jsonPath,
    RegexParser? regex,
    JsExecutor? js,
    LegadoRuleParser? legado,
    XpathParser? xpath,
  })  : _parser = parser ?? RuleParser(),
        _css = css ?? CssSelectorParser(),
        _jsonPath = jsonPath ?? JsonPathParser(),
        _regex = regex ?? RegexParser(),
        _js = js ?? JsExecutor(),
        _legado = legado ?? LegadoRuleParser(),
        _xpath = xpath ?? XpathParser();

  /// 对单值规则求值。
  ///
  /// - [input] 抓取到的原始文本（HTML / JSON / 纯文本）
  /// - [rule] 书源规则字符串（如 `css:.title@text`、`json:$.data.name`）
  /// - [baseUrl] / [book] 用于 `@js:` 规则的上下文变量
  String? eval(
    String input,
    String rule, {
    String? baseUrl,
    Map<String, dynamic>? book,
  }) {
    if (rule.isEmpty) return null;

    // 备选规则：依次尝试，返回首个非空结果
    // 单个备选抛异常（如 JS 执行失败、regex 非法）时跳过，尝试下一个
    final alternatives = _extractAlternatives(rule);
    for (final alt in alternatives) {
      try {
        final result = _evalSingle(input, alt, baseUrl: baseUrl, book: book);
        if (result != null && result.isNotEmpty) return result;
      } catch (_) {
        // 备选规则执行失败，尝试下一个
      }
    }
    return null;
  }

  /// 对列表规则求值（用于 bookList、chapterList 这类返回多节点的规则）。
  List<String> evalList(
    String input,
    String rule, {
    String? baseUrl,
    Map<String, dynamic>? book,
  }) {
    if (rule.isEmpty) return [];
    final alternatives = _extractAlternatives(rule);
    for (final alt in alternatives) {
      try {
        final result = _evalListSingle(input, alt, baseUrl: baseUrl, book: book);
        if (result.isNotEmpty) return result;
      } catch (_) {
        // 备选规则执行失败，尝试下一个
      }
    }
    return [];
  }

  /// 对 bookList 规则求值，返回 Element 列表。
  ///
  /// 用于「先取节点、再在每个节点上分别应用 name/author/bookUrl 规则」的场景。
  /// 后续配合 [evalOnElement] 使用。
  /// 支持 CSS、legado 旧式语法、XPath 三种规则。
  List<Element> evalElements(String html, String rule) {
    if (rule.isEmpty) return [];
    final alternatives = _extractAlternatives(rule);
    for (final alt in alternatives) {
      try {
        final elements = _evalElementsSingle(html, alt);
        if (elements.isNotEmpty) return elements;
      } catch (_) {
        // 备选规则执行失败，尝试下一个
      }
    }
    return [];
  }

  /// 在已选定的 Element 上应用规则。
  ///
  /// 用于：先用 [evalElements] 拿到 bookList 节点列表，
  /// 再对每个节点用本方法提取 name/author/coverUrl 等字段。
  String? evalOnElement(Element element, String rule) {
    if (rule.isEmpty) return null;

    final alternatives = _extractAlternatives(rule);
    for (final alt in alternatives) {
      try {
        final result = _evalOnElementSingle(element, alt);
        if (result != null && result.isNotEmpty) return result;
      } catch (_) {
        // 备选规则执行失败，尝试下一个
      }
    }
    return null;
  }

  // ---------- 备选规则拆分 ----------

  /// 把规则拆分为多个备选规则。
  ///
  /// legado 支持两种「备选」语法：
  ///   1. `<js>...</js><fallback>`：JS 失败或返回空时用 fallback
  ///      （如 笔阅读器 bookList: `<js>eval(...);decode(result);</js>$.result.list||$.result..list[*]`）
  ///   2. `rule1||rule2||rule3`：依次尝试，返回首个非空
  /// 两种可以组合。
  ///
  /// 注意：
  /// - `##regex##replacement` 净化段会被剥离后追加到每个备选规则末尾
  /// - `@regex:` / `regex:` 规则内的 `||` 是正则语义，不分割
  List<String> _extractAlternatives(String rule) {
    // 1. 剥离末尾的 ##purify 段（净化段不参与 || 分割）
    final purifyMatch = RegExp(r'##(.*)$').firstMatch(rule);
    final mainRule =
        purifyMatch != null ? rule.substring(0, purifyMatch.start) : rule;
    final purifyPart = purifyMatch != null ? rule.substring(purifyMatch.start) : '';

    final alternatives = <String>[];
    var rest = mainRule.trim();

    // 2. <js>...</js> 前缀：JS 作为第一个备选，剩余部分作为后续备选
    if (rest.startsWith('<js>')) {
      final endIdx = rest.indexOf('</js>');
      if (endIdx >= 0) {
        alternatives.add(rest.substring(0, endIdx + 5));
        rest = rest.substring(endIdx + 5).trim();
      }
    }

    // 3. || 分隔（regex 规则不分割，里面的 || 是正则语义）
    if (rest.contains('||') &&
        !rest.startsWith('@regex:') &&
        !rest.startsWith('regex:')) {
      alternatives.addAll(
          rest.split('||').map((s) => s.trim()).where((s) => s.isNotEmpty));
    } else if (rest.isNotEmpty) {
      alternatives.add(rest);
    }

    // 4. 把净化段加回到每个备选规则上
    if (purifyPart.isNotEmpty) {
      return alternatives.map((a) => a + purifyPart).toList();
    }
    return alternatives;
  }

  // ---------- 单备选规则的求值 ----------

  String? _evalSingle(
    String input,
    String rule, {
    String? baseUrl,
    Map<String, dynamic>? book,
  }) {
    // 处理规则末尾的 `##regex##replacement` 净化段
    final purifyMatch = RegExp(r'##(.*)$').firstMatch(rule);
    final cleanRule =
        purifyMatch != null ? rule.substring(0, purifyMatch.start) : rule;
    final purifyPart = purifyMatch?.group(1);

    String? result;
    switch (_parser.detect(cleanRule)) {
      case RuleType.css:
        result = _css.queryFirst(input, cleanRule);
        break;
      case RuleType.json:
        result = _jsonPath.queryFirst(input, cleanRule);
        break;
      case RuleType.regex:
        result = _regex.queryFirst(input, cleanRule);
        break;
      case RuleType.js:
        result = _js.eval(input, cleanRule, baseUrl: baseUrl, book: book);
        break;
      case RuleType.plain:
        // 含 {{$.path}} 模板的规则（如 /novels/api/book/{{$.book_id}}）：
        // 把每个 {{$.path}} 用 JSONPath 从 input 中提取的值替换。
        // input 非 JSON 或路径不存在时，对应位置替换为空串。
        if (RegExp(r'\{\{\$\.').hasMatch(cleanRule)) {
          result = _substituteJsonTemplate(cleanRule, input);
        } else {
          result = cleanRule;
        }
        break;
      case RuleType.legado:
        result = _legado.queryFirst(input, cleanRule);
        break;
      case RuleType.xpath:
        result = _xpath.queryFirst(input, cleanRule);
        break;
    }

    // 应用净化规则 ##regex##replacement
    if (result != null && purifyPart != null && purifyPart.isNotEmpty) {
      result = _applyPurify(result, purifyPart);
    }
    return result;
  }

  /// 把模板中的 `{{$.path}}` 用 JSONPath 从 [jsonInput] 提取的值替换。
  ///
  /// 用于 legado 书源里 URL 模板场景：
  ///   - searchUrl 的 bookUrl: `/novels/api/book/{{$.book_id}}`
  ///   - ruleBookInfo 的 tocUrl: `/novels/api/book/{{$.book_id}}/chapters?paging=0`
  ///   - ruleToc 的 chapterUrl: `/novels/api/book/{{$.book_id}}/chapters/{{$.chapter_id}}`
  ///
  /// 模板中的 `{{$.path}}` 会被替换为对应 JSONPath 查询结果；
  /// 查询失败（路径不存在 / input 非 JSON）时替换为空串。
  /// 不含 `{{$.` 的模板原样返回。
  String _substituteJsonTemplate(String template, String jsonInput) {
    if (!template.contains('{{\$')) return template;
    final trimmedInput = jsonInput.trim();
    if (!trimmedInput.startsWith('{') && !trimmedInput.startsWith('[')) {
      return template;
    }
    final regExp = RegExp(r'\{\{\$([^}]+)\}\}');
    return template.replaceAllMapped(regExp, (m) {
      final path = m.group(1)!;
      // 路径以 . 开头（如 $.book_id → path 是 .book_id）
      // 也可能直接是字段名（如 $book_id → path 是 book_id）
      var jsonPath = path.startsWith('.') ? '\$$path' : '\$.$path';
      try {
        return _jsonPath.queryFirst(jsonInput, jsonPath) ?? '';
      } catch (_) {
        return '';
      }
    });
  }

  List<String> _evalListSingle(
    String input,
    String rule, {
    String? baseUrl,
    Map<String, dynamic>? book,
  }) {
    switch (_parser.detect(rule)) {
      case RuleType.css:
        return _css.queryList(input, rule);
      case RuleType.json:
        return _jsonPath.queryList(input, rule);
      case RuleType.regex:
        return _regex.queryList(input, rule);
      case RuleType.js:
        final single = _js.eval(input, rule, baseUrl: baseUrl, book: book);
        return single == null ? [] : [single];
      case RuleType.plain:
        return [rule];
      case RuleType.legado:
        // legado 旧式语法的列表场景：返回每个元素的 text
        return _legado
            .queryElements(input, rule)
            .map((e) => e.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      case RuleType.xpath:
        return _xpath.queryList(input, rule);
    }
  }

  List<Element> _evalElementsSingle(String html, String rule) {
    switch (_parser.detect(rule)) {
      case RuleType.css:
        return _css.queryElements(html, rule);
      case RuleType.legado:
        return _legado.queryElements(html, rule);
      case RuleType.xpath:
        return _xpath.queryElements(html, rule);
      case RuleType.json:
        // JSON 规则返回字符串列表，无法转 Element；调用方应改用 evalList
        return [];
      default:
        return [];
    }
  }

  String? _evalOnElementSingle(Element element, String rule) {
    // 处理净化段
    final purifyMatch = RegExp(r'##(.*)$').firstMatch(rule);
    final cleanRule =
        purifyMatch != null ? rule.substring(0, purifyMatch.start) : rule;
    final purifyPart = purifyMatch?.group(1);

    String? result;
    switch (_parser.detect(cleanRule)) {
      case RuleType.css:
        result = _css.extract(element, cleanRule);
        break;
      case RuleType.legado:
        result = _legado.extract(element, cleanRule);
        break;
      case RuleType.plain:
        result = cleanRule;
        break;
      case RuleType.xpath:
        // 对单个 Element，把其 outerHtml 作为文档重新解析
        result = _xpath.queryFirst(element.outerHtml, cleanRule);
        break;
      // 其他类型（json/regex/js）对单个 Element 没有标准语义，
      // 退化为：把 element.outerHtml 作为字符串输入再走原 eval
      case RuleType.json:
      case RuleType.regex:
      case RuleType.js:
        result = _evalSingle(element.outerHtml, cleanRule);
        break;
    }

    if (result != null && purifyPart != null && purifyPart.isNotEmpty) {
      result = _applyPurify(result, purifyPart);
    }
    return result;
  }

  /// 应用 `##regex##replacement` 净化规则。
  ///
  /// 格式：`regex##replacement`，其中 replacement 可省略（默认空字符串）。
  /// 多条规则用 `||` 分隔。
  /// 替换串中可引用捕获组：`$1`、`$2`、`$<name>`。
  ///
  /// 注意：Dart `String.replaceAll(RegExp, String)` 在正则**无捕获组**但
  /// replacement 含 `$1` 时会原样保留 `$1`，导致占位符泄露到结果里。
  /// 这里改用 `replaceAllMapped` 手动展开捕获组引用，无对应组时替换为空。
  String _applyPurify(String input, String purifyRule) {
    var result = input;
    // 支持 || 分隔多条净化规则
    for (final part in purifyRule.split('||')) {
      if (part.isEmpty) continue;
      final segs = part.split('##');
      if (segs.isEmpty) continue;
      final pattern = segs[0];
      final replacement = segs.length > 1 ? segs[1] : '';
      if (pattern.isEmpty) continue;
      try {
        final regExp = RegExp(pattern);
        if (replacement.contains('\$')) {
          // 含 $ 引用时手动展开，避免无捕获组时 $1 泄露
          result = result.replaceAllMapped(regExp,
              (m) => _expandPurifyReplacement(replacement, m));
        } else {
          result = result.replaceAll(regExp, replacement);
        }
      } catch (_) {
        // 正则语法错误时跳过
      }
    }
    return result;
  }

  /// 展开净化规则 replacement 中的 `$1`/`$2`/`${1}`/`$<name>` 引用。
  /// 捕获组不存在时替换为空串（而非原样保留 `$1`）。
  static final _purifyRefPattern = RegExp(r'\$(\d+|\{(\d+)\}|<([^>]+)>)');

  String _expandPurifyReplacement(String replacement, RegExpMatch m) {
    final buf = StringBuffer();
    var lastEnd = 0;
    for (final ref in _purifyRefPattern.allMatches(replacement)) {
      buf.write(replacement.substring(lastEnd, ref.start));
      final g1 = ref.group(1)!;
      String? value;
      if (g1.startsWith('{')) {
        final n = int.tryParse(ref.group(2)!);
        if (n != null) value = _safeGroup(m, n);
      } else if (g1.startsWith('<')) {
        value = m.namedGroup(ref.group(3)!);
      } else {
        final n = int.tryParse(g1);
        if (n != null) value = _safeGroup(m, n);
      }
      buf.write(value ?? '');
      lastEnd = ref.end;
    }
    buf.write(replacement.substring(lastEnd));
    return buf.toString();
  }

  String? _safeGroup(RegExpMatch m, int n) {
    try {
      return m.group(n);
    } catch (_) {
      return null;
    }
  }
}
