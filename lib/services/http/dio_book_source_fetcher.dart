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
///   - 支持 POST 请求（legado 书源的 searchUrl 常带 JSON 配置段）
///   - 支持书源自定义 header / charset / body
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
    // 合并 header：默认 UA → 书源自定义 header → 调用方传入 headers
    final mergedHeaders = <String, dynamic>{
      'User-Agent': _defaultUA,
    };
    final sourceHeader = _parseSourceHeader(source);
    if (sourceHeader != null) mergedHeaders.addAll(sourceHeader);
    mergedHeaders.addAll(headers ?? const {});

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        maxRedirects: 5,
        headers: mergedHeaders,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    final bytes = response.data ?? const <int>[];
    final charset = _detectCharset(response, bytes);
    return _decode(bytes, charset);
  }

  /// 按 [config] 发起请求（支持 POST / 自定义 body / 指定 charset）。
  ///
  /// 用于 legado 书源的 searchUrl JSON 配置段：
  ///   `url,{'method':'POST','body':'key={{key}}','charset':'gbk','headers':{...}}`
  Future<String> fetchWithConfig(RequestConfig config, {BookSource? source}) async {
    final mergedHeaders = <String, dynamic>{
      'User-Agent': _defaultUA,
    };
    final sourceHeader = _parseSourceHeader(source);
    if (sourceHeader != null) mergedHeaders.addAll(sourceHeader);
    if (config.headers != null) mergedHeaders.addAll(config.headers!);

    // POST body 编码：按 config.charset 编码 body
    List<int>? bodyBytes;
    if (config.body != null && config.body!.isNotEmpty) {
      bodyBytes = _encodeBody(config.body!, config.charset);
      mergedHeaders['Content-Type'] =
          'application/x-www-form-urlencoded; charset=${config.charset ?? 'utf-8'}';
    }

    final response = await _dio.request<List<int>>(
      config.url,
      data: bodyBytes,
      options: Options(
        method: config.method.toUpperCase(),
        responseType: ResponseType.bytes,
        followRedirects: true,
        maxRedirects: 5,
        headers: mergedHeaders,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );

    final bytes = response.data ?? const <int>[];
    // 优先用 config 指定的 charset，其次自动探测
    final charset = config.charset ?? _detectCharset(response, bytes);
    return _decode(bytes, charset);
  }

  /// 解析书源的 header 字段（可能是 JSON 字符串或 @js: 规则）。
  ///
  /// 仅支持纯 JSON 字符串格式，@js: 格式暂不支持（需 JS 执行环境）。
  Map<String, String>? _parseSourceHeader(BookSource? source) {
    if (source == null) return null;
    final raw = source.header;
    if (raw == null || raw.isEmpty) return null;
    // @js: 格式暂不支持
    if (raw.trim().startsWith('@js:') || raw.trim().startsWith('<js>')) {
      return null;
    }
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return parsed.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {
      // JSON 解析失败，忽略
    }
    return null;
  }

  /// 按 charset 编码 POST body。
  ///
  /// 对于 `application/x-www-form-urlencoded` 格式的 body（如 `key1=val1&key2=val2`），
  /// 按标准做法：对每个参数值先用 [charset] 编码，再做 percent-encode（URL 编码），
  /// 最后拼接为 body 字符串并编码为 ASCII 字节。
  ///
  /// 非 form 格式的 body（如 JSON）直接按 charset 编码。
  List<int> _encodeBody(String body, String? charset) {
    // 判断是否是 form 格式（含 = 和 &）
    if (body.contains('=') && (body.contains('&') || body.startsWith('s='))) {
      return _encodeFormBody(body, charset);
    }
    // 非 form 格式，直接编码
    switch (charset?.toLowerCase()) {
      case 'gbk':
      case 'gb2312':
      case 'gb18030':
        try {
          return gbk.encode(body);
        } catch (_) {
          return utf8.encode(body);
        }
      default:
        return utf8.encode(body);
    }
  }

  /// URL 编码 form body 的参数值。
  List<int> _encodeFormBody(String body, String? charset) {
    final pairs = body.split('&');
    final encoded = <String>[];
    for (final pair in pairs) {
      final eqIdx = pair.indexOf('=');
      if (eqIdx < 0) {
        encoded.add(pair);
        continue;
      }
      final key = pair.substring(0, eqIdx);
      final value = pair.substring(eqIdx + 1);
      // 对 value 按 charset 编码后再 percent-encode
      final valueBytes = _encodeString(value, charset);
      final percentEncoded = _percentEncode(valueBytes);
      encoded.add('$key=$percentEncoded');
    }
    return utf8.encode(encoded.join('&'));
  }

  /// 按 charset 编码字符串为字节。
  List<int> _encodeString(String s, String? charset) {
    switch (charset?.toLowerCase()) {
      case 'gbk':
      case 'gb2312':
      case 'gb18030':
        try {
          return gbk.encode(s);
        } catch (_) {
          return utf8.encode(s);
        }
      default:
        return utf8.encode(s);
    }
  }

  /// percent-encode（URL 编码）字节序列。
  ///
  /// 与 Dart 内置的 `Uri.encodeQueryComponent` 不同的是，这里按实际字节编码，
  /// 而非按 UTF-8。对于 GBK 等非 UTF-8 编码，必须手动编码。
  String _percentEncode(List<int> bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      // RFC 3986 unreserved: A-Z, a-z, 0-9, -, _, ., ~
      if ((b >= 0x41 && b <= 0x5A) || // A-Z
          (b >= 0x61 && b <= 0x7A) || // a-z
          (b >= 0x30 && b <= 0x39) || // 0-9
          b == 0x2D || b == 0x5F || b == 0x2E || b == 0x7E) {
        buf.writeCharCode(b);
      } else {
        buf.write('%');
        buf.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return buf.toString();
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

/// 请求配置（从 legado searchUrl 的 JSON 配置段解析得到）。
class RequestConfig {
  final String url;
  final String method; // GET / POST
  final String? body; // POST body
  final String? charset; // 指定编码
  final Map<String, String>? headers;

  RequestConfig({
    required this.url,
    this.method = 'GET',
    this.body,
    this.charset,
    this.headers,
  });
}
