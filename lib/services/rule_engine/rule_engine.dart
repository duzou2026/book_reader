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
    // 处理规则末尾的 `##regex##replacement` 净化段
    final purifyMatch = RegExp(r'##(.*)$').firstMatch(rule);
    final cleanRule = purifyMatch != null ? rule.substring(0, purifyMatch.start) : rule;
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
        result = cleanRule;
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

  /// 对列表规则求值（用于 bookList、chapterList 这类返回多节点的规则）。
  List<String> evalList(
    String input,
    String rule, {
    String? baseUrl,
    Map<String, dynamic>? book,
  }) {
    if (rule.isEmpty) return [];
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

  /// 对 bookList 规则求值，返回 Element 列表。
  ///
  /// 用于「先取节点、再在每个节点上分别应用 name/author/bookUrl 规则」的场景。
  /// 后续配合 [evalOnElement] 使用。
  /// 支持 CSS、legado 旧式语法、XPath 三种规则。
  List<Element> evalElements(String html, String rule) {
    if (rule.isEmpty) return [];
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

  /// 在已选定的 Element 上应用规则。
  ///
  /// 用于：先用 [evalElements] 拿到 bookList 节点列表，
  /// 再对每个节点用本方法提取 name/author/coverUrl 等字段。
  String? evalOnElement(Element element, String rule) {
    if (rule.isEmpty) return null;
    // 处理净化段
    final purifyMatch = RegExp(r'##(.*)$').firstMatch(rule);
    final cleanRule = purifyMatch != null ? rule.substring(0, purifyMatch.start) : rule;
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
        result = eval(element.outerHtml, cleanRule);
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
        result = result.replaceAll(RegExp(pattern), replacement);
      } catch (_) {
        // 正则语法错误时跳过
      }
    }
    return result;
  }
}
