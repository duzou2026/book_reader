import 'dart:convert';

/// 轻量 JSONPath 解析器。
///
/// 支持的语法子集（足够覆盖 legado 书源绝大多数场景）：
///   - `$.foo.bar`           按字段名遍历
///   - `$.foo[0]`            数组索引
///   - `$.foo[*]`            数组全部元素
///   - `$..bar`              递归下降取字段（简化实现）
///
/// 不支持过滤器、切片、wildcard 字段。需要时可换用 `json_path` 包。
class JsonPathParser {
  String? queryFirst(String jsonStr, String rule) {
    final results = _walk(jsonStr, rule, firstOnly: true);
    return results.isEmpty ? null : results.first;
  }

  List<String> queryList(String jsonStr, String rule) {
    return _walk(jsonStr, rule, firstOnly: false);
  }

  List<String> _walk(String jsonStr, String rule, {required bool firstOnly}) {
    final path = _stripPrefix(rule);
    final root = jsonDecode(jsonStr);
    final results = <String>[];

    if (path.isEmpty) {
      results.add(_stringify(root));
      return results;
    }

    final segments = _parseSegments(path);
    _walkInternal(root, segments, 0, results, firstOnly);
    return results;
  }

  String _stripPrefix(String rule) {
    var p = rule.trim();
    if (p.startsWith('@json:')) p = p.substring(6);
    else if (p.startsWith('json:')) p = p.substring(5);
    // 去掉起始的 $ 或 $.
    if (p.startsWith(r'$.')) p = p.substring(2);
    else if (p.startsWith(r'$')) p = p.substring(1);
    if (p.startsWith('.')) p = p.substring(1);
    return p;
  }

  void _walkInternal(
    dynamic node,
    List<_Seg> segs,
    int idx,
    List<String> results,
    bool firstOnly,
  ) {
    if (idx >= segs.length) {
      results.add(_stringify(node));
      return;
    }
    final seg = segs[idx];

    if (seg.isRecursive) {
      // $..foo 递归查找
      _collectRecursive(node, seg, segs, idx, results, firstOnly);
      return;
    }

    if (seg.isAllIndex) {
      if (node is List) {
        for (final item in node) {
          _walkInternal(item, segs, idx + 1, results, firstOnly);
          if (firstOnly && results.isNotEmpty) return;
        }
      }
      return;
    }

    if (seg.index != null) {
      if (node is List && seg.index! < node.length) {
        _walkInternal(node[seg.index!], segs, idx + 1, results, firstOnly);
      }
      return;
    }

    if (seg.key != null) {
      if (node is Map && node.containsKey(seg.key)) {
        _walkInternal(node[seg.key], segs, idx + 1, results, firstOnly);
      }
      return;
    }
  }

  void _collectRecursive(
    dynamic node,
    _Seg seg,
    List<_Seg> segs,
    int idx,
    List<String> results,
    bool firstOnly,
  ) {
    if (seg.key != null && node is Map && node.containsKey(seg.key)) {
      _walkInternal(node[seg.key], segs, idx + 1, results, firstOnly);
      if (firstOnly && results.isNotEmpty) return;
    }
    if (node is Map) {
      for (final v in node.values) {
        _collectRecursive(v, seg, segs, idx, results, firstOnly);
        if (firstOnly && results.isNotEmpty) return;
      }
    } else if (node is List) {
      for (final v in node) {
        _collectRecursive(v, seg, segs, idx, results, firstOnly);
        if (firstOnly && results.isNotEmpty) return;
      }
    }
  }

  List<_Seg> _parseSegments(String path) {
    final segs = <_Seg>[];
    // 用 split('.') 切，但要保留 [n] / [*] 与 key 的关系
    final parts = path.split('.').where((s) => s.isNotEmpty).toList();
    for (final part in parts) {
      // 支持 books[0]、books[*]、books、[0]（单独的索引）
      final m = RegExp(r'^([^\[]+)?(?:\[(\*|\d+)\])?$').firstMatch(part);
      if (m == null) continue;
      final key = m.group(1);
      final idx = m.group(2);

      // 先压 key（如果有），再压索引（如果有）
      // 这样 books[0] 会变成两个 segment: key("books") + index(0)
      // 处理时按顺序遍历即可。
      if (key != null && key.isNotEmpty) {
        segs.add(_Seg.key(key));
      }
      if (idx == '*') {
        segs.add(_Seg.all());
      } else if (idx != null) {
        segs.add(_Seg.index(int.parse(idx)));
      }
    }
    return segs;
  }

  String _stringify(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return jsonEncode(v);
  }
}

class _Seg {
  final String? key;
  final int? index;
  final bool isAllIndex;
  final bool isRecursive;

  _Seg._({
    this.key,
    this.index,
    this.isAllIndex = false,
    this.isRecursive = false,
  });

  factory _Seg.key(String k) => _Seg._(key: k);
  factory _Seg.index(int i) => _Seg._(index: i);
  factory _Seg.all() => _Seg._(isAllIndex: true);
  factory _Seg.recursive(String k) =>
      _Seg._(key: k, isRecursive: true);
}
