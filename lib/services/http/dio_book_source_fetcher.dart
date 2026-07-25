import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/http/book_source_fetcher.dart';
import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';

/// 基于 Dio 的 [BookSourceFetcher] 实现。
///
/// 关键设计：
///   - 用 `ResponseType.bytes` 拿原始字节，避免 dio 自动按 UTF-8 解码
///   - 按 Content-Type charset → HTML meta charset → 默认 UTF-8 顺序探测编码
///   - 默认 UA 模拟桌面 Chrome，避免被站点屏蔽
class DioBookSourceFetcher implements BookSourceFetcher {
  final Dio _dio;
  static const _defaultUA =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  DioBookSourceFetcher([Dio? dio]) : _dio = dio ?? Dio();

  @override
  Future<String> fetch(
    String url, {
    BookSource? source,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'User-Agent': _defaultUA,
          ...?headers,
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    final bytes = response.data ?? const <int>[];
    final charset = _detectCharset(response, bytes);
    return _decode(bytes, charset);
  }

  /// 探测响应内容的字符编码。
  ///
  /// 优先级：
  ///   1. HTTP `Content-Type: ...; charset=xxx`
  ///   2. HTML head 中 `<meta charset="xxx">` 或 `<meta http-equiv="Content-Type" content="...; charset=xxx">`
  ///   3. 默认 `utf-8`
  String _detectCharset(Response<List<int>> response, List<int> bytes) {
    // 1. Content-Type
    final ct = response.headers.value('content-type') ?? '';
    final ctMatch =
        RegExp(r'charset=([\w-]+)', caseSensitive: false).firstMatch(ct);
    if (ctMatch != null) {
      return ctMatch.group(1)!.toLowerCase();
    }

    // 2. HTML meta（只看前 2KB 够了）
    final head = String.fromCharCodes(bytes.take(2048));
    final metaMatch =
        RegExp("charset=[\"']?([\\w-]+)", caseSensitive: false)
            .firstMatch(head);
    if (metaMatch != null) {
      return metaMatch.group(1)!.toLowerCase();
    }

    return 'utf-8';
  }

  String _decode(List<int> bytes, String charset) {
    switch (charset) {
      case 'gbk':
      case 'gb2312':
      case 'gb18030':
        try {
          return gbk.decode(bytes);
        } catch (_) {
          // GBK 解码失败时退回 UTF-8（容 malformed）
          return utf8.decode(bytes, allowMalformed: true);
        }
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
