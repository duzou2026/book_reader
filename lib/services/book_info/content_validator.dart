/// 正文有效性判定。
///
/// 用于跨书源回退时区分"真实正文"与"VIP 占位页/错误页"。
class ContentValidator {
  /// 常见付费/错误提示关键词。命中任一即视为无效正文。
  static const _invalidKeywords = [
    'vip章节',
    'vip章节未购买',
    '本章为vip',
    '本章是vip',
    '请登录后查看',
    '请登录后阅读',
    '登录后查看',
    '登录后阅读',
    '本章未购买',
    '请充值',
    '请购买本章',
    '购买本章后',
    '购买后查看',
    '购买后阅读',
    '已下架',
    '内容已删除',
    '页面不存在',
    '404',
    '请购买vip',
    '开通vip',
    '订阅本章',
    '请订阅',
  ];

  /// 有效正文的最小长度（字符数）。
  /// 短于这个长度的几乎可以确定是占位文字。
  static const _minValidLength = 20;

  /// 判断正文是否有效。
  ///
  /// 有效条件：
  ///   1. 非空
  ///   2. 长度 >= [_minValidLength]
  ///   3. 不包含任一 [_invalidKeywords] 中的关键词（忽略大小写）
  static bool isValid(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length < _minValidLength) return false;
    final lower = trimmed.toLowerCase();
    for (final kw in _invalidKeywords) {
      if (lower.contains(kw)) return false;
    }
    return true;
  }

  /// 判断章节是否明确标记为 VIP。
  /// （来自书源 ruleToc.isVip 字段）
  static bool isVip(bool isVipFlag, String content) {
    if (isVipFlag) return true;
    return !isValid(content);
  }
}
