import 'package:book_reader/data/models/book_source.dart';

/// 书源 HTTP 拉取器抽象。
///
/// 把「URL + BookSource 配置」转换成 HTTP 请求，返回解码后的字符串。
/// 实现需要处理：
///   - 字符编码（GBK / GB2312 / UTF-8）
///   - User-Agent（部分站点拒绝默认 dio UA）
///   - Cookie / 登录态（部分书源需要）
///   - 重定向
///
/// 抽象出来便于测试时注入 fake。
abstract class BookSourceFetcher {
  /// 拉取 [url] 并返回解码后的字符串。
  ///
  /// - [source] 提供书源级别的配置（如自定义 header、登录 cookie）
  /// - [headers] 调用方临时覆盖的 headers
  Future<String> fetch(
    String url, {
    BookSource? source,
    Map<String, String>? headers,
  });
}
