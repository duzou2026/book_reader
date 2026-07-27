import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// legado 旧式规则语法解析器。
///
/// legado 书源生态早期使用一套自创的规则语法（非标准 CSS），形如：
///   `class.book-info.0@tag.a.0@text`
///   `tag.img.0@src`
///   `id.content@tag.p@text`
///   `class.author@tag.a!0@text`
///
/// 语法规则：
///   - 整个规则用 `@` 分段，每段是一个「定位步骤」
///   - 最后一段若是属性名（text/href/src/...），则用于属性提取
///   - 每个步骤格式：`<type>.<name>.<index>` 或 `<type>.<name>`
///     - `class.xxx` → 选 class=xxx 的元素
///     - `id.xxx`    → 选 id=xxx 的元素
///     - `tag.xxx`   → 选标签名为 xxx 的元素
///     - `.N`        → 取第 N 个子元素（N 从 0 开始，负数表示倒数）
///     - `xxx`       → 若是已知属性名则提取属性，否则视为标签名
///   - `!N`         → 取第 N 个（legado 语义略有不同，这里近似处理）
///   - 末尾可带 `##regex##replacement` 净化（由调用方处理，本类只负责定位+提取）
///
/// 本解析器把上述语法转换成对 DOM 树的逐步筛选，复用 html 包的 Element API。
class LegadoRuleParser {
  /// 在 `html` 中按 `rule` 查找首个匹配，返回提取的字符串。
  String? queryFirst(String html, String rule) {
    final elements = queryElements(html, _stripPurify(rule));
    if (elements.isEmpty) return null;
    return _extractAttr(elements.first, _extractAttrName(rule));
  }

  /// 在 `html` 中按 `rule` 查找所有匹配，返回 Element 列表。
  ///
  /// 注意：rule 末尾的属性名会被剥离，只返回定位到的元素。
  List<Element> queryElements(String html, String rule) {
    final cleanRule = _stripPurify(rule);
    final steps = _parseSteps(cleanRule);
    if (steps.isEmpty) return [];

    final doc = html_parser.parse(html);
    final root = doc.documentElement;
    if (root == null) return [];
    return _applySteps(root, steps);
  }

  /// 在已选定的 Element 上按 rule 提取字段。
  ///
  /// 用于：先用 [queryElements] 拿到 bookList 节点列表，
  /// 再对每个节点用本方法提取 name/author/coverUrl 等字段。
  String? extract(Element element, String rule) {
    final cleanRule = _stripPurify(rule);
    final steps = _parseSteps(cleanRule);
    if (steps.isEmpty) {
      // 整个 rule 就是属性名（如 "text"）
      return _extractAttr(element, _extractAttrName(rule));
    }
    final results = _applySteps(element, steps);
    if (results.isEmpty) return null;
    return _extractAttr(results.first, _extractAttrName(rule));
  }

  /// 判断一个规则字符串是否是 legado 旧式语法。
  ///
  /// 判定标准（满足任一）：
  ///   - 含 `class.` / `tag.` / `id.` / `children.` 前缀
  ///   - 含多个 `@` 步骤分隔符（如 `#author@tbody@tr!0`）
  ///   - 含 `!N` 末尾索引语法（如 `tag.a!0`）
  ///
  /// 不视为 legado 的情形：
  ///   - 单个 `@` 后接已知属性名（如 `.title@text`）→ 这是 CSS + 属性提取器
  static bool isLegadoRule(String rule) {
    final trimmed = rule.trim();
    // 去掉前缀（虽然旧式语法通常不带前缀，但保险起见）
    var r = trimmed;
    for (final p in ['@css:', 'css:', '@xpath:', 'xpath:', '@json:', 'json:',
      '@regex:', 'regex:', '@js:', 'js:']) {
      if (r.startsWith(p)) {
        r = r.substring(p.length);
        break;
      }
    }
    // 1. 含 legado 旧式类型前缀：class. / tag. / id. / children.
    if (RegExp(r'^(class|tag|id|children)\.').hasMatch(r)) return true;
    // bare `children`（无后续 .name）也是 legado 旧式语法，表示取直接子元素。
    // _parseStep 已支持把 bare `children` 解析为取子元素列表的步骤。
    if (r == 'children') return true;
    // 2. 含 !N 末尾索引 → legado 索引语法
    if (RegExp(r'!\d+').hasMatch(r)) return true;
    // 3. 含 @ 步骤分隔符
    if (r.contains('@')) {
      // 排除 JSONPath（$ 开头）
      if (r.startsWith(r'$')) return false;
      final atCount = '@'.allMatches(r).length;
      if (atCount >= 2) {
        // 多个 @ → legado 步骤链（CSS 不会用 @ 串接）
        return true;
      }
      // 单个 @：可能是 CSS + 属性提取器（如 .foo@text），不视为 legado
      return false;
    }
    return false;
  }

  // ---------- 内部实现 ----------

  /// 去掉末尾的 `##regex##replacement` 净化段。
  String _stripPurify(String rule) {
    final idx = rule.indexOf('##');
    if (idx >= 0) return rule.substring(0, idx);
    return rule;
  }

  /// 从规则末尾提取属性名。
  ///
  /// 规则最后一段若是已知属性名（text/href/src/...），则视为属性提取；
  /// 否则默认提取 text。
  String _extractAttrName(String rule) {
    final clean = _stripPurify(rule);
    final parts = clean.split('@');
    if (parts.isEmpty) return 'text';
    final last = parts.last.trim();
    // 已知属性名
    const knownAttrs = {
      'text', 'textNodes', 'html', 'innerHTML', 'outerHTML', 'ownText',
      'href', 'src', 'title', 'name', 'value', 'content', 'data-src',
      'data-original', 'data-bid', 'alt',
    };
    // 若最后一段不含 `.`（不是选择器），且是已知属性名或形如属性名
    if (!last.contains('.') && _looksLikeAttr(last)) {
      return last;
    }
    return 'text';
  }

  bool _looksLikeAttr(String s) {
    return RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$').hasMatch(s);
  }

  /// 把规则字符串解析成「步骤列表」。
  ///
  /// 每个步骤是 `_Step`（类型 + 名称 + 索引）。
  /// 最后一段若是属性名，会被剥离（不作为步骤）。
  List<_Step> _parseSteps(String rule) {
    final rawSteps = rule.split('@');
    final steps = <_Step>[];

    for (var i = 0; i < rawSteps.length; i++) {
      final s = rawSteps[i].trim();
      if (s.isEmpty) continue;

      // 判断是否是属性名（仅最后一段可能）
      final isLast = (i == rawSteps.length - 1);
      if (isLast && !s.contains('.') && _looksLikeAttr(s)) {
        // 这是属性名，不属于选择器步骤
        continue;
      }

      final step = _parseStep(s);
      if (step != null) steps.add(step);
    }
    return steps;
  }

  /// 解析单个步骤。
  ///
  /// 支持的形态：
  ///   - `class.book-info.0` / `tag.a` / `id.content` / `children` （旧式类型前缀）
  ///   - `#author` / `.item` （CSS-like 简写：#id / .class）
  ///   - `tbody` / `tr` （纯标签名）
  ///   - `0` / `1` （数字索引）
  ///   - 上述任一 + `!N` 末尾索引（如 `tag.a!0` / `tr!0`）
  _Step? _parseStep(String s) {
    if (s.isEmpty) return null;

    var index = 0;
    var hasIndex = false;

    // 处理 `!N` 索引语法（legado 的排除/索引语义）
    var working = s;
    final bangMatch = RegExp(r'!(-?\d+)$').firstMatch(working);
    if (bangMatch != null) {
      index = int.parse(bangMatch.group(1)!);
      hasIndex = true;
      working = working.substring(0, bangMatch.start);
    }
    if (working.isEmpty) return null;

    // CSS-like 简写：#id / .class
    if (working.startsWith('#') && working.length > 1) {
      return _Step('id', working.substring(1), index, hasIndex);
    }
    if (working.startsWith('.') && working.length > 1) {
      return _Step('class', working.substring(1), index, hasIndex);
    }

    final parts = working.split('.');
    if (parts.isEmpty) return null;

    // legado 旧式类型前缀：class.xxx / tag.xxx / id.xxx / children
    if (parts[0] == 'class' || parts[0] == 'tag' || parts[0] == 'id' ||
        parts[0] == 'children') {
      final type = parts[0];
      final name = parts.length >= 2 ? parts[1] : '';
      var idx = index;
      var hasIdx = hasIndex;
      if (parts.length >= 3) {
        idx = int.tryParse(parts[2]) ?? 0;
        hasIdx = true;
      }
      return _Step(type, name, idx, hasIdx);
    }

    // 纯数字 → 索引
    if (parts.length == 1 && _isInt(parts[0])) {
      return _Step('index', '', int.parse(parts[0]), true);
    }
    // 形如 "tag.0" → 退化为索引
    if (parts.length == 2 && _isInt(parts[1])) {
      return _Step('index', '', int.parse(parts[1]), true);
    }

    // 退化为标签名
    var tagName = parts[0];
    var idx = index;
    var hasIdx = hasIndex;
    if (parts.length >= 2 && _isInt(parts[1])) {
      idx = int.parse(parts[1]);
      hasIdx = true;
    }
    return _Step('tag', tagName, idx, hasIdx);
  }

  bool _isInt(String s) => int.tryParse(s) != null;

  /// 对一组元素应用步骤链。
  List<Element> _applySteps(Element root, List<_Step> steps) {
    var current = <Element>[root];
    for (final step in steps) {
      final next = <Element>[];
      for (final el in current) {
        next.addAll(_applyStep(el, step));
      }
      current = next;
      if (current.isEmpty) break;
    }
    return current;
  }

  /// 对单个元素应用一个步骤，返回匹配的子元素列表。
  List<Element> _applyStep(Element parent, _Step step) {
    List<Element> matches;
    switch (step.type) {
      case 'class':
        matches = parent.getElementsByClassName(step.name);
        break;
      case 'id':
        final el = parent.querySelector('#${step.name}');
        matches = el == null ? <Element>[] : [el];
        break;
      case 'tag':
        matches = parent.getElementsByTagName(step.name);
        break;
      case 'children':
        matches = parent.children;
        break;
      case 'index':
        matches = parent.children;
        break;
      default:
        matches = <Element>[];
    }

    if (step.hasIndex && matches.isNotEmpty) {
      final idx = step.index;
      if (idx >= 0 && idx < matches.length) {
        return [matches[idx]];
      } else if (idx < 0 && matches.length + idx >= 0) {
        // 负数索引：倒数
        return [matches[matches.length + idx]];
      }
      return [];
    }
    return matches;
  }

  /// 从 Element 提取属性值。
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

/// 一个定位步骤。
class _Step {
  final String type; // class / tag / id / children / index
  final String name; // 元素名（class名/标签名/id名）
  final int index;   // 索引（从 0 开始，负数倒数）
  final bool hasIndex;
  _Step(this.type, this.name, this.index, this.hasIndex);
}
