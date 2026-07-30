import 'dart:convert';

/// 书源发现页分类（legado exploreUrl 解析结果）。
///
/// [url] 为空表示该项是分组标题（仅用于展示，不抓取）。
class ExploreCategory {
  final String title;
  final String url;

  const ExploreCategory({required this.title, required this.url});

  /// 是否为分组标题（url 为空时仅用于展示，不发起请求）。
  bool get isHeader => url.isEmpty;
}

/// legado exploreUrl 字段解析器。
///
/// legado 的 exploreUrl 有两种常见格式：
///   1. JSON 数组：`[{"title":"男频","url":"/rank/1","style":{...}},...]`
///      —— 解析 title 和 url，忽略 style。url 为空的项是分类标题分隔符。
///   2. 文本对：`分类名::url\n分类名::url` 或 `分类名::url,{json配置}`
///      —— 按换行分割，每行按 `::` 分割出 title 和 url。
///
/// url 里的 `{{page}}` 占位符保留，运行时由 [buildUrl] 替换为页码。
class ExploreUrlParser {
  /// 解析 [exploreUrl] 字符串，输出分类列表 [List<ExploreCategory>]。
  ///
  /// 解析失败或内容为空时返回空列表。
  static List<ExploreCategory> parse(String? exploreUrl) {
    if (exploreUrl == null) return [];
    final raw = exploreUrl.trim();
    if (raw.isEmpty) return [];

    // JSON 数组格式：以 [ 开头
    if (raw.startsWith('[')) {
      return _parseJsonArray(raw);
    }

    // 文本对格式：按换行分割
    return _parseTextPairs(raw);
  }

  /// 解析 JSON 数组格式。
  static List<ExploreCategory> _parseJsonArray(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return [];
    }
    if (decoded is! List) return [];

    final result = <ExploreCategory>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final title = (item['title'] ?? '').toString().trim();
      // url 可能为空（分组标题分隔符），保留空串
      final url = (item['url'] ?? '').toString().trim();
      if (title.isEmpty && url.isEmpty) continue;
      result.add(ExploreCategory(title: title, url: url));
    }
    return result;
  }

  /// 解析文本对格式：`分类名::url`，每行一项。
  ///
  /// 行内可能带 `,{json配置}`（如 `玄幻::/xuanhuan/p{{page}}.html,{...}`），
  /// 此时取 `::` 后、`,` 前的部分作为 url，丢弃 JSON 配置段
  /// （发现页通常不需要 POST/charset 配置，简单 GET 即可）。
  static List<ExploreCategory> _parseTextPairs(String raw) {
    final result = <ExploreCategory>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final sepIdx = trimmed.indexOf('::');
      if (sepIdx < 0) {
        // 没有 :: 分隔符：若该行非空，作为分组标题（url 为空）
        result.add(ExploreCategory(title: trimmed, url: ''));
        continue;
      }

      final title = trimmed.substring(0, sepIdx).trim();
      var url = trimmed.substring(sepIdx + 2).trim();

      // 去掉末尾的 ,{json配置} 段（如 url,{...}）
      final jsonIdx = _findJsonConfigStart(url);
      if (jsonIdx >= 0) {
        url = url.substring(0, jsonIdx).trim();
      }

      if (title.isEmpty && url.isEmpty) continue;
      result.add(ExploreCategory(title: title, url: url));
    }
    return result;
  }

  /// 查找 url 中 `,{` 配置段的起始位置（返回 `,` 的索引，未找到返回 -1）。
  ///
  /// 仅匹配 `,{` 形式的 JSON 配置段起始，避免误伤 URL 自身的查询参数
  /// （URL 里的 `,` 通常不以 `{` 紧随其后）。
  static int _findJsonConfigStart(String url) {
    for (var i = 0; i < url.length - 1; i++) {
      if (url[i] == ',' && url[i + 1] == '{') return i;
    }
    return -1;
  }

  /// 构造分类的最终请求 URL。
  ///
  ///   1. 替换 `{{page}}` 为 [page]（页码）
  ///   2. 用 [Uri.resolve] 把相对 URL 拼到 [baseUrl]（书源 bookSourceUrl）上
  ///
  /// 已经是绝对 URL（http/https 开头）则原样返回。
  static String buildUrl(ExploreCategory cat, int page, String baseUrl) {
    var url = cat.url.replaceAll('{{page}}', page.toString());
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    try {
      return Uri.parse(baseUrl).resolve(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }
}
