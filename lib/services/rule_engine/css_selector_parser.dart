import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// CSS 选择器解析器。
///
/// legado 书源的 CSS 规则语法形如：
///   `<selector>@<attr>`
///
/// 其中 `<attr>` 可以是：
///   - `text` / `textNodes` → 元素的纯文本
///   - `html` / `innerHTML`  → 元素的 innerHtml
///   - `outerHTML`           → 元素的 outerHtml
///   - 任意 HTML 属性名（如 `href`、`src`、`title`） → 对应属性值
///
/// 若不指定 `@attr`，默认取 `text`。
class CssSelectorParser {
  /// 在 `html` 中按 `rule` 查找首个匹配，返回提取的字符串。
  String? queryFirst(String html, String rule) {
    final parts = _splitRule(rule);
    if (parts.selector.isEmpty) return null;
    final doc = html_parser.parse(html);
    final element = doc.querySelector(parts.selector);
    if (element == null) return null;
    return _extractAttr(element, parts.attr ?? 'text');
  }

  /// 在 `html` 中按 `rule` 查找所有匹配，返回提取的字符串列表。
  List<String> queryList(String html, String rule) {
    final parts = _splitRule(rule);
    if (parts.selector.isEmpty) return [];
    final doc = html_parser.parse(html);
    final elements = doc.querySelectorAll(parts.selector);
    return elements
        .map((e) => _extractAttr(e, parts.attr ?? 'text') ?? '')
        .toList();
  }

  /// 返回 Element 列表（用于 bookList 这种「先取节点、再分字段」的场景）。
  /// 注意：这里 selector 不带 @attr 后缀。
  List<Element> queryElements(String html, String selector) {
    final clean = _stripPrefix(selector);
    return html_parser.parse(html).querySelectorAll(clean);
  }

  /// 从已选定的 Element 上按 rule 提取字段。
  /// rule 可以是 `.foo@text`（先在 element 内查找再提取）或 `@text`（直接取自身）。
  String? extract(Element element, String rule) {
    final parts = _splitRule(rule);
    Element? target;
    if (parts.selector.isEmpty) {
      target = element;
    } else {
      target = element.querySelector(parts.selector);
    }
    if (target == null) return null;
    return _extractAttr(target, parts.attr ?? 'text');
  }

  String _stripPrefix(String rule) {
    var p = rule.trim();
    if (p.startsWith('@css:')) return p.substring(5);
    if (p.startsWith('css:')) return p.substring(4);
    return p;
  }

  _RuleParts _splitRule(String rule) {
    final stripped = _stripPrefix(rule);
    if (stripped.isEmpty) return _RuleParts('', null);

    // 形如 "@text" —— 整个 rule 就是 attr，selector 为空
    if (stripped.startsWith('@')) {
      final maybeAttr = stripped.substring(1);
      if (_looksLikeAttr(maybeAttr)) {
        return _RuleParts('', maybeAttr);
      }
    }

    // 形如 "selector@attr"
    final idx = stripped.lastIndexOf('@');
    if (idx <= 0) {
      return _RuleParts(stripped, null);
    }
    final maybeSelector = stripped.substring(0, idx);
    final maybeAttr = stripped.substring(idx + 1);
    if (_looksLikeAttr(maybeAttr)) {
      return _RuleParts(maybeSelector, maybeAttr);
    }
    return _RuleParts(stripped, null);
  }

  bool _looksLikeAttr(String s) {
    // attr 通常是字母数字，可能带下划线，不含空格 / > / # / .
    return RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(s);
  }

  String? _extractAttr(Element element, String attr) {
    switch (attr) {
      case 'text':
      case 'textNodes':
        return element.text.trim();
      case 'html':
      case 'innerHTML':
        return element.innerHtml.trim();
      case 'outerHTML':
        return element.outerHtml.trim();
      case 'ownText':
        return element.nodes
            .whereType<Text>()
            .map((t) => t.data.trim())
            .where((s) => s.isNotEmpty)
            .join(' ');
      default:
        return element.attributes[attr];
    }
  }
}

class _RuleParts {
  final String selector;
  final String? attr;
  _RuleParts(this.selector, this.attr);
}
