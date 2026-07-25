import 'package:html/dom.dart';

import 'css_selector_parser.dart';
import 'js_executor.dart';
import 'jsonpath_parser.dart';
import 'regex_parser.dart';
import 'rule_parser.dart';

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

  RuleEngine({
    RuleParser? parser,
    CssSelectorParser? css,
    JsonPathParser? jsonPath,
    RegexParser? regex,
    JsExecutor? js,
  })  : _parser = parser ?? RuleParser(),
        _css = css ?? CssSelectorParser(),
        _jsonPath = jsonPath ?? JsonPathParser(),
        _regex = regex ?? RegexParser(),
        _js = js ?? JsExecutor();

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
    switch (_parser.detect(rule)) {
      case RuleType.css:
        return _css.queryFirst(input, rule);
      case RuleType.json:
        return _jsonPath.queryFirst(input, rule);
      case RuleType.regex:
        return _regex.queryFirst(input, rule);
      case RuleType.js:
        return _js.eval(input, rule, baseUrl: baseUrl, book: book);
      case RuleType.plain:
        return rule;
      case RuleType.xpath:
        throw UnimplementedError('xpath 暂未实现');
    }
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
      case RuleType.xpath:
        throw UnimplementedError('xpath 暂未实现');
    }
  }

  /// 对 bookList 规则求值，返回 Element 列表（仅 CSS 规则支持）。
  ///
  /// 用于「先取节点、再在每个节点上分别应用 name/author/bookUrl 规则」的场景。
  /// 后续配合 [evalOnElement] 使用。
  List<Element> evalElements(String html, String rule) {
    if (rule.isEmpty) return [];
    switch (_parser.detect(rule)) {
      case RuleType.css:
        return _css.queryElements(html, rule);
      default:
        throw UnimplementedError('evalElements 仅支持 CSS 规则');
    }
  }

  /// 在已选定的 Element 上应用规则。
  ///
  /// 用于：先用 [evalElements] 拿到 bookList 节点列表，
  /// 再对每个节点用本方法提取 name/author/coverUrl 等字段。
  String? evalOnElement(Element element, String rule) {
    if (rule.isEmpty) return null;
    switch (_parser.detect(rule)) {
      case RuleType.css:
        return _css.extract(element, rule);
      case RuleType.plain:
        return rule;
      // 其他类型（json/regex/js）对单个 Element 没有标准语义，
      // 退化为：把 element.outerHtml 作为字符串输入再走原 eval
      case RuleType.json:
      case RuleType.regex:
      case RuleType.js:
        return eval(element.outerHtml, rule);
      case RuleType.xpath:
        throw UnimplementedError('xpath 暂未实现');
    }
  }
}
