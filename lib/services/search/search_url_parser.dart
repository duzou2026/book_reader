import 'dart:convert';

import 'package:book_reader/services/http/dio_book_source_fetcher.dart';
import 'package:book_reader/services/rule_engine/rule_context.dart';

/// legado searchUrl 解析器。
///
/// legado 的 searchUrl 格式可能是：
///   1. 纯 URL：`https://example.com/search?q={{key}}`
///   2. URL + JSON 配置：`url,{'method':'POST','body':'key={{key}}','charset':'gbk','headers':{...}}`
///   3. `@js:` / `<js>...</js>` 前缀的 JS 规则：
///      - 完整 JS 逻辑（如番茄小说）暂不支持，返回 null
///      - **常见简化模式**会静态提取 URL：
///        a. `<js>side-effect code</js><actual_url>` → 取 `</js>` 之后的内容
///           （如 69书吧2、和图书：JS 仅做 human verification，URL 在 `</js>` 后）
///        b. `@js:url="<url_with_config>";...` → 提取双引号中的 URL
///           （如 大文学无错、思路客、顶点小说、八一中文）
///        c. `@js:url=baseUrl+"<path_with_config>";...` → 提取 path 并拼到 baseUrl 前
///           （如 起点中文）
///
/// 本解析器把格式 1、2 以及 3a/3b/3c 转换为 [RequestConfig]，并完成 `{{key}}`/`{{page}}` 替换。
class SearchUrlParser {
  /// 解析 searchUrl 字符串，返回 [RequestConfig]。
  ///
  /// [keyword] 搜索关键词，[page] 页码（从 1 开始）。
  /// [baseUrl] 书源的 bookSourceUrl，用于 `url=baseUrl+"..."` 模式。
  /// 返回 null 表示无法解析（如复杂 @js: 规则）。
  static RequestConfig? parse(
    String searchUrl, {
    required String keyword,
    int page = 1,
    String? baseUrl,
  }) {
    var raw = searchUrl.trim();
    if (raw.isEmpty) return null;

    final ctx = RuleContext(keyword: keyword, page: page);

    // ---- @js: / <js> 规则：尝试静态提取 URL ----
    if (raw.startsWith('@js:') ||
        raw.startsWith('js:') ||
        raw.startsWith('<js>')) {
      return _parseJsRule(raw, ctx, baseUrl);
    }

    // ---- 纯 URL 或 URL + JSON 配置 ----
    // 检测是否带 JSON 配置段：url,{...}
    // 注意：URL 本身可能含 ,（如查询参数），所以只匹配末尾的 {...}
    final jsonMatch = RegExp(r",\s*(\{.*\})\s*$").firstMatch(raw);
    if (jsonMatch == null) {
      // 纯 URL，GET 请求
      final url = _resolveUrl(ctx.substitute(raw), baseUrl);
      return RequestConfig(url: url, method: 'GET');
    }

    final urlPart = raw.substring(0, jsonMatch.start).trim();
    final jsonPart = jsonMatch.group(1)!;

    Map<String, dynamic>? config;
    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is Map<String, dynamic>) {
        config = decoded;
      }
    } catch (_) {
      // JSON 解析失败，退化为纯 URL
    }

    if (config == null) {
      final url = _resolveUrl(ctx.substitute(raw), baseUrl);
      return RequestConfig(url: url, method: 'GET');
    }

    final url = _resolveUrl(ctx.substitute(urlPart), baseUrl);
    return _buildFromConfig(url, config, ctx);
  }

  /// 把相对 URL 解析为绝对 URL。
  ///
  /// legado 书源的 searchUrl 经常是相对路径（如 `/search.html?q={{key}}`），
  /// 需要拼到 `baseUrl`（书源 bookSourceUrl）上才能请求。
  /// - 已经是绝对 URL（http/https 开头）→ 原样返回
  /// - `//host/path` → 补 https:
  /// - `/path` 或 `path` → 用 [Uri.resolve] 拼到 baseUrl
  static String _resolveUrl(String url, String? baseUrl) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (baseUrl == null || baseUrl.isEmpty) return trimmed;
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    try {
      return Uri.parse(baseUrl).resolve(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }

  /// 解析 `@js:` / `<js>` 形式的 searchUrl。
  ///
  /// 返回 null 表示无法静态提取（需要真实 JS 执行环境）。
  static RequestConfig? _parseJsRule(
    String raw,
    RuleContext ctx,
    String? baseUrl,
  ) {
    // 模式 A: `<js>...</js><actual_url_or_path>`
    // JS 通常是 side-effect（人机验证、toast 等），URL 在 `</js>` 之后
    if (raw.startsWith('<js>')) {
      final endIdx = raw.indexOf('</js>');
      if (endIdx >= 0 && endIdx + 5 < raw.length) {
        final after = raw.substring(endIdx + 5).trim();
        if (after.isNotEmpty) {
          // 递归调用 parse 处理剩余部分（去掉 <js> 前缀后走正常流程）
          return parse(after, keyword: ctx.keyword, page: ctx.page, baseUrl: baseUrl);
        }
      }
      // `<js>` 内部就是全部内容，无 fallback → 无法静态提取
      return null;
    }

    // @js: 前缀，取表达式部分
    var expr = raw;
    if (expr.startsWith('@js:')) {
      expr = expr.substring(4).trim();
    } else if (expr.startsWith('js:')) {
      expr = expr.substring(3).trim();
    }

    // 模式 B: `url="<url_with_config>";...` 或 `url='<url>';...`
    // 形如：url="https://m.wcxsw.org/search.php,{...}";if(java.ajax(url)...)
    // 注意：URL 内的 JSON 配置段含单引号，所以必须按"同种引号闭合"匹配，
    // 不能用 `[^"']+`（会在 JSON 内的单引号处错误停止）。
    // 使用反向引用 \1 确保开始和结束是同一种引号。
    final directMatch =
        RegExp(r'''url\s*=\s*(["'])(.*?)\1''').firstMatch(expr);
    if (directMatch != null) {
      final extracted = directMatch.group(2)!;
      // 递归处理（可能含 JSON 配置段）
      return parse(extracted, keyword: ctx.keyword, page: ctx.page, baseUrl: baseUrl);
    }

    // 模式 C: `url=baseUrl+"<path_with_config>";...` 或 `url=baseUrl+'<path>';...`
    // 形如：url=baseUrl+"/so/{{key}}.html,{...}";java.put('url',url);result=url;
    final baseConcatMatch =
        RegExp(r'''url\s*=\s*baseUrl\s*\+\s*(["'])(.*?)\1''').firstMatch(expr);
    if (baseConcatMatch != null) {
      final path = baseConcatMatch.group(2)!;
      if (baseUrl != null && baseUrl.isNotEmpty) {
        final fullUrl = '$baseUrl$path';
        return parse(fullUrl, keyword: ctx.keyword, page: ctx.page, baseUrl: baseUrl);
      }
      // 无 baseUrl 也可以尝试用 path（如果是绝对 URL）
      return parse(path, keyword: ctx.keyword, page: ctx.page, baseUrl: baseUrl);
    }

    // 其他复杂 JS 表达式（含 if/for/function 等）暂不支持
    return null;
  }

  /// 从 URL + JSON config map 构造 [RequestConfig]。
  static RequestConfig _buildFromConfig(
    String url,
    Map<String, dynamic> config,
    RuleContext ctx,
  ) {
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
    final processedHeaders =
        headers?.map((k, v) => MapEntry(k, ctx.substitute(v)));

    return RequestConfig(
      url: url,
      method: method,
      body: processedBody,
      charset: charset,
      headers: processedHeaders,
    );
  }
}
