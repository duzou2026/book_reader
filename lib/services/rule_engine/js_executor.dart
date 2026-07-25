import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

/// JS 执行器，用于书源规则中的 `@js:` 表达式。
///
/// legado 书源大量使用 JS 来处理复杂逻辑（编码、签名、字段拼接）。
/// 我们将上次抓取到的原始输入（HTML 或 JSON 字符串）注入为 `result` 变量，
/// 同时提供 `baseUrl`、`book`、`java`（部分兼容桩）等上下文变量。
///
/// 注意：JS 执行是同步的。flutter_js 在 Android/iOS 上各自内嵌了 QuickJS /
/// JavaScriptCore，性能足够规则解析使用。
class JsExecutor {
  static JavascriptRuntime? _runtime;

  JavascriptRuntime get _rt => _runtime ??= getJavascriptRuntime();

  /// 执行 `rule` 表达式，返回字符串结果。
  ///
  /// - `input` 注入为 `result` 变量。若看起来是 JSON 字符串则原样注入，
  ///   否则当字符串字面量（自动加引号、转义）。
  /// - `baseUrl` 注入为 `baseUrl` 变量（可选）。
  /// - `book` 注入为 `book` 变量（可选，Map）。
  String? eval(String input, String rule, {String? baseUrl, Map<String, dynamic>? book}) {
    final expr = _stripRule(rule);

    final setup = StringBuffer();
    setup.writeln('var result = ${_jsLiteral(input)};');
    if (baseUrl != null) {
      setup.writeln('var baseUrl = ${_jsLiteral(baseUrl)};');
    } else {
      setup.writeln('var baseUrl = "";');
    }
    if (book != null) {
      setup.writeln('var book = ${_jsLiteral(book)};');
    } else {
      setup.writeln('var book = {};');
    }
    // 简易 java 兼容桩（legado 规则里常用，比如 java.encode()）
    setup.writeln('var java = {'
        'encode: (s) => encodeURIComponent(s),'
        'log: (s) => s'
        '};');

    _rt.evaluate(setup.toString());
    final res = _rt.evaluate(expr);
    final raw = res.stringResult;

    // flutter_js 对 string 结果会带引号，这里去一层
    if (raw.startsWith('"') && raw.endsWith('"')) {
      return _unesquote(raw.substring(1, raw.length - 1));
    }
    return raw;
  }

  String _stripRule(String rule) {
    var p = rule.trim();
    if (p.startsWith('<js>') && p.endsWith('</js>')) {
      return p.substring(4, p.length - 5).trim();
    }
    if (p.startsWith('@js:')) return p.substring(4).trim();
    if (p.startsWith('js:')) return p.substring(3).trim();
    return p;
  }

  String _jsLiteral(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return value;
      }
      // 字符串字面量
      final escaped = value
          .replaceAll(r'\', r'\\')
          .replaceAll("'", r"\'")
          .replaceAll('\n', r'\n')
          .replaceAll('\r', r'\r');
      return "'$escaped'";
    }
    if (value == null) return 'null';
    if (value is num || value is bool) return value.toString();
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return "'${value}'";
  }

  String _unesquote(String s) {
    return s
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\\', r'\');
  }
}
