import 'dart:convert';

import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_context.dart';

/// legado searchUrl 解析器。
///
/// legado 的 searchUrl 格式可能是：
///   1. 纯 URL：`https://example.com/search?q={{key}}`
///   2. URL + JSON 配置：`url,{'method':'POST','body':'key={{key}}','charset':'gbk','headers':{...}}`
///   3. @js: 前缀的 JS 规则（暂不支持，返回 null 让调用方跳过）
///
/// 本解析器把格式 1 和 2 转换为 [RequestConfig]，并完成 `{{key}}`/`{{page}}` 替换。
class SearchUrlParser {
  /// 解析 searchUrl 字符串，返回 [RequestConfig]。
  ///
  /// [keyword] 搜索关键词，[page] 页码（从 1 开始）。
  /// 返回 null 表示无法解析（如 @js: 规则）。
  static RequestConfig? parse(
    String searchUrl, {
    required String keyword,
    int page = 1,
  }) {
    var raw = searchUrl.trim();
    if (raw.isEmpty) return null;

    // @js: / <js> 规则暂不支持
    if (raw.startsWith('@js:') ||
        raw.startsWith('js:') ||
        raw.startsWith('<js>')) {
      return null;
    }

    // 检测是否带 JSON 配置段：url,{...}
    // 注意：URL 本身可能含 ,（如查询参数），所以只匹配末尾的 {...}
    final jsonMatch = RegExp(r",\s*(\{.*\})\s*$").firstMatch(raw);
    if (jsonMatch == null) {
      // 纯 URL，GET 请求
      final ctx = RuleContext(keyword: keyword, page: page);
      final url = ctx.substitute(raw);
      return RequestConfig(url: url, method: 'GET');
    }

    final urlPart = raw.substring(0, jsonMatch.start).trim();
    final jsonPart = jsonMatch.group(1)!;

    Map<String, dynamic>? config;
    try {
      config = jsonDecode(jsonPart) as Map<String, dynamic>?;
    } catch (_) {
      // JSON 解析失败，退化为纯 URL
      final ctx = RuleContext(keyword: keyword, page: page);
      final url = ctx.substitute(raw);
      return RequestConfig(url: url, method: 'GET');
    }

    final ctx = RuleContext(keyword: keyword, page: page);
    final url = ctx.substitute(urlPart);
    final method = (config['method'] as String?)?.toUpperCase() ?? 'GET';
    final body = config['body'] as String?;
    final charset = config['charset'] as String?;

    // 解析 headers
    Map<String, String>? headers;
    final rawHeaders = config['headers'];
    if (rawHeaders is Map<String, dynamic>) {
      headers = rawHeaders.map((k, v) => MapEntry(k, v.toString()));
    }

    // 替换 body 中的 {{key}} / {{page}}
    final processedBody = body != null ? ctx.substitute(body) : null;
    // 替换 headers value 中的 {{key}} / {{page}}
    final processedHeaders = headers?.map((k, v) => MapEntry(k, ctx.substitute(v)));

    return RequestConfig(
      url: url,
      method: method,
      body: processedBody,
      charset: charset,
      headers: processedHeaders,
    );
  }
}
