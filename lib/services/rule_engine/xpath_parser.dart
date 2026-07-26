import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// 轻量 XPath 解析器（仅支持 legado 书源常用的子集）。
///
/// 支持的 XPath 语法：
///   - `//tag`                     → 任意深度的 tag 元素
///   - `//tag[@attr='val']`        → 带 属性=值 过滤的元素
///   - `//tag[@attr]`              → 带某属性的元素
///   - `/tag`                      → 直接子元素
///   - `//tag/@attr`               → 提取属性值
///   - `//tag/text()`              → 提取文本
///   - `//tag[1]`                  → 按位置取（从 1 开始）
///   - 多段路径：`//a/b`            → a 下的 b
///
/// 不支持：轴（ancestor::/following::）、函数（contains/position）等高级特性。
/// 这些高级特性在 legado 书源中较少使用。
class XpathParser {
  /// 在 `html` 中按 `rule` 查找首个匹配，返回提取的字符串。
  String? queryFirst(String html, String rule) {
    final elements = _queryElements(html, rule);
    if (elements.isEmpty) return null;
    return _extractFromElement(elements.first, rule);
  }

  /// 在 `html` 中按 `rule` 查找所有匹配，返回字符串列表。
  List<String> queryList(String html, String rule) {
    final elements = _queryElements(html, rule);
    return elements
        .map((e) => _extractFromElement(e, rule))
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 返回 Element 列表（用于 bookList 这类「先取节点、再分字段」的场景）。
  List<Element> queryElements(String html, String rule) {
    return _queryElements(html, rule);
  }

  // ---------- 内部实现 ----------

  String _stripPrefix(String rule) {
    var p = rule.trim();
    if (p.startsWith('@xpath:')) return p.substring(7);
    if (p.startsWith('xpath:')) return p.substring(6);
    return p;
  }

  /// 解析 XPath 规则，返回步骤列表。
  ///
  /// 把 `//tag[@attr='val']/@attr` 拆成：
  ///   [Step(descendant: true, tag: 'tag', attrFilter: ('attr', 'val')),
  ///    Step(extractAttr: 'attr')]
  List<_XpathStep> _parsePath(String path) {
    final steps = <_XpathStep>[];
    // 标准化：去掉开头的 /
    var p = path;
    while (p.startsWith('/')) {
      p = p.substring(1);
    }

    // 按路径段拆分，但要正确处理 //（descendant）和 [] 内的 /
    // 简化处理：先按 `/` 拆，再合并 `//` 开头的段
    final segments = <String>[];
    var current = '';
    var inBracket = 0;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (c == '[') inBracket++;
      if (c == ']') inBracket = (inBracket > 0) ? inBracket - 1 : 0;
      if (c == '/' && inBracket == 0) {
        if (current.isNotEmpty) segments.add(current);
        current = '';
      } else {
        current += c;
      }
    }
    if (current.isNotEmpty) segments.add(current);

    // 处理每段
    var descendant = false;
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      // 解析 tag[attr='val'][1] 这种格式
      final step = _parseSegment(seg, descendant);
      if (step != null) steps.add(step);
      descendant = false; // 只有第一段可能是 //
    }

    return steps;
  }

  _XpathStep? _parseSegment(String seg, bool descendant) {
    // 形如 tag[@attr='val'][1] 或 @attr 或 text()
    final trimmed = seg.trim();
    if (trimmed.isEmpty) return null;

    // 纯属性提取：@attr
    if (trimmed.startsWith('@')) {
      return _XpathStep(
        descendant: descendant,
        tag: '',
        extractAttr: trimmed.substring(1),
      );
    }

    // text() 函数
    if (trimmed == 'text()' || trimmed == 'text') {
      return _XpathStep(
        descendant: descendant,
        tag: '',
        extractText: true,
      );
    }

    // 提取 tag 名（在 [ 之前）
    var tagEnd = trimmed.indexOf('[');
    final tag = tagEnd > 0 ? trimmed.substring(0, tagEnd) : trimmed;

    // 解析 [xxx] 过滤器
    final filters = <_AttrFilter>[];
    var position = 0;
    var hasPosition = false;
    var rest = tagEnd > 0 ? trimmed.substring(tagEnd) : '';
    while (rest.isNotEmpty && rest.startsWith('[')) {
      final endIdx = _findClosingBracket(rest);
      if (endIdx < 0) break;
      final inner = rest.substring(1, endIdx);
      rest = rest.substring(endIdx + 1);

      // 尝试解析为位置 [1]
      final posMatch = RegExp(r'^(\d+)$').firstMatch(inner.trim());
      if (posMatch != null) {
        position = int.parse(posMatch.group(1)!);
        hasPosition = true;
        continue;
      }

      // 解析 [@attr='val'] 或 [@attr]
      final attrMatch =
          RegExp(r"^@([\w-]+)(?:='([^']*)'|=\"([^\"]*)\"|=(.+))?$")
              .firstMatch(inner.trim());
      if (attrMatch != null) {
        final attrName = attrMatch.group(1)!;
        final attrVal = attrMatch.group(2) ??
            attrMatch.group(3) ??
            attrMatch.group(4);
        filters.add(_AttrFilter(attrName, attrVal, attrVal == null));
      }
    }

    return _XpathStep(
      descendant: descendant,
      tag: tag,
      attrFilters: filters,
      position: position,
      hasPosition: hasPosition,
    );
  }

  int _findClosingBracket(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '[') depth++;
      if (s[i] == ']') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  List<Element> _queryElements(String html, String rawRule) {
    final rule = _stripPrefix(rawRule);
    final steps = _parsePath(rule);
    if (steps.isEmpty) return [];

    final doc = html_parser.parse(html);
    var current = <Element>[doc.documentElement!];

    for (final step in steps) {
      current = _applyStep(current, step);
      if (current.isEmpty) break;
    }
    return current;
  }

  List<Element> _applyStep(List<Element> parents, _XpathStep step) {
    final result = <Element>[];

    // 属性提取步骤不产生 Element
    if (step.extractAttr != null || step.extractText) {
      return parents; // 由 _extractFromElement 处理
    }

    for (final parent in parents) {
      if (step.descendant) {
        // //tag：在所有后代中查找
        if (step.tag.isEmpty) {
          result.addAll(_allDescendants(parent));
        } else {
          result.addAll(parent.getElementsByTagName(step.tag));
        }
      } else {
        // /tag：直接子元素
        for (final child in parent.children) {
          if (step.tag.isEmpty || child.localName == step.tag) {
            result.add(child);
          }
        }
      }
    }

    // 应用属性过滤
    var filtered = result;
    if (step.attrFilters.isNotEmpty) {
      filtered = result.where((el) {
        for (final f in step.attrFilters) {
          final val = el.attributes[f.name];
          if (f.justExists) {
            if (val == null) return false;
          } else {
            if (val != f.value) return false;
          }
        }
        return true;
      }).toList();
    }

    // 应用位置过滤
    if (step.hasPosition) {
      // XPath 位置从 1 开始
      final idx = step.position - 1;
      if (idx >= 0 && idx < filtered.length) {
        return [filtered[idx]];
      }
      return [];
    }

    return filtered;
  }

  List<Element> _allDescendants(Element root) {
    final result = <Element>[];
    void collect(Element el) {
      for (final child in el.children) {
        result.add(child);
        collect(child);
      }
    }
    collect(root);
    return result;
  }

  String? _extractFromElement(Element element, String rawRule) {
    final rule = _stripPrefix(rawRule);
    final steps = _parsePath(rule);
    if (steps.isEmpty) return element.text.trim();

    // 最后一个步骤决定提取方式
    final lastStep = steps.last;
    if (lastStep.extractAttr != null) {
      final attr = lastStep.extractAttr!;
      if (attr == 'text' || attr == 'text()') {
        return element.text.trim();
      }
      return element.attributes[attr];
    }
    if (lastStep.extractText) {
      return element.text.trim();
    }
    // 默认返回 text
    return element.text.trim();
  }
}

/// XPath 路径的一个步骤。
class _XpathStep {
  final bool descendant; // 是否为 //（后代查找）
  final String tag;
  final List<_AttrFilter> attrFilters;
  final int position;
  final bool hasPosition;
  final String? extractAttr; // 提取的属性名（如 @href）
  final bool extractText; // text() 函数

  _XpathStep({
    this.descendant = false,
    this.tag = '',
    this.attrFilters = const [],
    this.position = 0,
    this.hasPosition = false,
    this.extractAttr,
    this.extractText = false,
  });
}

/// 属性过滤器。
class _AttrFilter {
  final String name;
  final String? value;
  final bool justExists; // [@attr] 只判断存在性

  _AttrFilter(this.name, this.value, this.justExists);
}
