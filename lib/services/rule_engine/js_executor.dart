import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

/// JS 执行器，用于书源规则中的 `@js:` 表达式。
///
/// legado 书源大量使用 JS 来处理复杂逻辑（编码、签名、字段拼接）。
/// 我们将上次抓取到的原始输入（HTML 或 JSON 字符串）注入为 `result` 变量，
/// 同时提供 `baseUrl`、`book`、`java`（部分兼容桩）等上下文变量。
///
/// 注意：JS 执行是同步的。flutter_js 在 Android/iOS 上各自内嵌了 QuickJS /
/// JavaScriptCore，性能足够规则解析使用。因此 `java.ajax/get/post` 等异步
/// 网络方法无法真正实现（返回空字符串），用这些方法的 JS 规则会失效。
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
    // java 兼容桩：覆盖 legado 书源常用的 java.xxx 调用。
    // 网络相关方法（ajax/get/post/getCookie）因 JS 同步执行无法真正实现，
    // 返回空字符串/空数组；编码/时间格式化等纯函数可正常工作。
    setup.writeln(_javaStub);

    try {
      _rt.evaluate(setup.toString());
      final res = _rt.evaluate(expr);
      final raw = res.stringResult;

      // flutter_js 对 string 结果会带引号，这里去一层
      if (raw.startsWith('"') && raw.endsWith('"')) {
        return _unesquote(raw.substring(1, raw.length - 1));
      }
      return raw;
    } catch (_) {
      // JS 执行失败（语法错误 / 运行时错误 / native FFI 异常）
      // 返回 null 让 RuleEngine 回退到下一个备选规则
      return null;
    }
  }

  /// java 兼容桩 JS 代码。
  ///
  /// 实现 legado 书源常用的 java.xxx 方法：
  ///   - 编码：encode / encodeURI / encodeURI / base64Encode / base64Decode
  ///   - 时间：timeFormat / timeFormatUTC
  ///   - 网络（桩，返回空）：ajax / get / post / getString / getCookie / put
  ///   - UI（桩，无操作）：toast / longToast / log
  ///   - 其他（桩）：androidId / hexDecodeToString / t2s / getVerificationCode /
  ///     startBrowserAwait / setContent / getElement / get
  static const String _javaStub = r'''
var java = {
  // 编码
  encode: (s) => encodeURIComponent(s),
  encodeURI: (s) => encodeURI(s),
  encodeURIComponent: (s) => encodeURIComponent(s),
  base64Encode: (s) => {
    try { return btoa(unescape(encodeURIComponent(s))); } catch(e) { return ''; }
  },
  base64Decode: (s) => {
    try { return decodeURIComponent(escape(atob(s))); } catch(e) { return ''; }
  },
  hexDecodeToString: (s) => {
    try {
      let r = '';
      for (let i = 0; i < s.length; i += 2) {
        r += String.fromCharCode(parseInt(s.substr(i, 2), 16));
      }
      return r;
    } catch(e) { return ''; }
  },
  // 时间格式化
  timeFormat: (ts) => {
    try {
      let d = new Date(typeof ts === 'number' ? ts : parseInt(ts));
      if (isNaN(d.getTime())) return '';
      let pad = (n) => n < 10 ? '0' + n : '' + n;
      return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
        ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
    } catch(e) { return ''; }
  },
  timeFormatUTC: (ts) => {
    try {
      let d = new Date(typeof ts === 'number' ? ts : parseInt(ts));
      if (isNaN(d.getTime())) return '';
      let pad = (n) => n < 10 ? '0' + n : '' + n;
      return d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1) + '-' + pad(d.getUTCDate()) +
        ' ' + pad(d.getUTCHours()) + ':' + pad(d.getUTCMinutes());
    } catch(e) { return ''; }
  },
  // 网络相关（同步环境无法真正实现，返回空）
  ajax: (url) => '',
  get: (url) => '',
  post: (url, body) => '',
  getString: (url) => '',
  getCookie: (key) => '',
  put: (key, val) => {},
  // UI（桩，无操作）
  log: (s) => s,
  toast: (s) => s,
  longToast: (s) => s,
  // 其他桩
  androidId: '',
  getVerificationCode: (url) => '',
  startBrowserAwait: (url, selector) => '',
  setContent: (s) => {},
  getElement: (rule) => [],
  // cookie 操作桩
  removeCookie: (url) => {}
};
''';

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
