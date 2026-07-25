/// 规则变量上下文。
///
/// 处理书源 `searchUrl` 等模板字符串中的变量替换：
///   - `{{key}}`  → 搜索关键词
///   - `{{page}}` → 分页页码
///   - `{{<var>}}` → 通过 [put] 注入的自定义变量（如 token、签名）
///
/// 当模板以 `http` 开头时，对 `{{key}}` 自动做 URL 编码；
/// `{{page}}` 始终是数字，无需编码。
class RuleContext {
  final String keyword;
  final int page;
  final Map<String, String> _vars = {};

  RuleContext({required this.keyword, required this.page});

  /// 注入一个自定义变量。
  void put(String key, String value) => _vars[key] = value;

  /// 读取一个自定义变量。
  String? get(String key) => _vars[key];

  /// 在模板上做变量替换。
  String substitute(String template) {
    var result = template;

    final isUrl = template.startsWith('http');
    final keyEncoded = isUrl ? Uri.encodeComponent(keyword) : keyword;

    result = result.replaceAll('{{key}}', keyEncoded);
    result = result.replaceAll('{{page}}', page.toString());

    for (final entry in _vars.entries) {
      final v = isUrl ? Uri.encodeComponent(entry.value) : entry.value;
      result = result.replaceAll('{{${entry.key}}}', v);
    }

    return result;
  }
}
