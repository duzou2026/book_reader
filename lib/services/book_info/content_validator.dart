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
    // 反爬限流提示（如"免登陆次数用尽，请登录后查看"）
    '免登陆次数',
    '免登录次数',
    '次数用尽',
    '今日已达上限',
    '访问频繁',
    // 更多反爬/限流提示
    '访问过于频繁',
    '人机验证',
    '请完成验证',
    '请输入验证码',
    '安全验证',
    '访问受限',
    '请求过多',
    '请求过于频繁',
    '检测到异常访问',
    '请稍后再试',
    '系统繁忙',
    '服务器繁忙',
    '当前访问人数较多',
    '被防火墙拦截',
    '拒绝访问',
    'access denied',
    'too many requests',
    // 更多付费/登录提示变体
    '余额不足',
    '书币不足',
    '需要订阅',
    '需要购买',
    '仅限会员',
    '会员专享',
    '需开通会员',
  ];

  /// 反爬验证页特征正则。
  ///
  /// 起点等站点对无 Cookie 请求返回 JS 验证页（HTTP 202 + ~200 字节）
  /// 而非正文，靠关键字子串匹配识别不到。这里命中任一即视为无效。
  /// 正则已带 HTML/JS 结构约束，正常正文不会误伤。
  static final _antiCrawlPatterns = [
    RegExp(r'var\s+buid'),
    RegExp(r'<title>\s*(验证|blocked|verify|安全验证)', caseSensitive: false),
    // Cloudflare 5秒盾 / 挑战页
    RegExp(r'challenges\.cloudflare\.com', caseSensitive: false),
    RegExp(r'cloudflare-static', caseSensitive: false),
    RegExp(r'_cf_chl_opt', caseSensitive: false),
    RegExp(r'cf-turnstile', caseSensitive: false),
    RegExp(r'<title>\s*[^<]*Cloudflare', caseSensitive: false),
    // 5秒盾/盾云/盾安全
    RegExp(r'5\s*秒.*盾', caseSensitive: false),
    RegExp(r'shield\.js', caseSensitive: false),
    RegExp(r'jxdun\.com', caseSensitive: false),
    // reCAPTCHA / hCaptcha
    RegExp(r'google\.com/recaptcha', caseSensitive: false),
    RegExp(r'hcaptcha\.com', caseSensitive: false),
    // JS 重定向验证（window.location）
    RegExp(r'window\.location\s*=.*verify', caseSensitive: false),
    RegExp(r'setTimeout.*location', caseSensitive: false),
    // HTTP 503 维护页
    RegExp(r'<title>\s*503', caseSensitive: false),
    RegExp(r'service\s*unavailable', caseSensitive: false),
    // DDoS 保护页
    RegExp(r'ddos.*protection', caseSensitive: false),
    RegExp(r'anti.*bot', caseSensitive: false),
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
  ///   4. 不命中任一 [_antiCrawlPatterns] 反爬验证页正则
  static bool isValid(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length < _minValidLength) return false;
    final lower = trimmed.toLowerCase();
    for (final kw in _invalidKeywords) {
      if (lower.contains(kw)) return false;
    }
    for (final p in _antiCrawlPatterns) {
      if (p.hasMatch(trimmed)) return false;
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
