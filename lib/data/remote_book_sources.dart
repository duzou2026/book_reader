import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 远程书源获取器：从 GitHub 仓库拉取书源 JSON，并写入 Hive 缓存。
///
/// 设计目标：
///   1. **不内置到 APK**：书源 JSON 提交到 GitHub 仓库根目录
///      `book_sources/xiu2_sources.json`，APK 体积不增加
///   2. **可热更新**：新增/删除书源只需修改 GitHub 上的 JSON 文件，
///      用户在书源管理页点「刷新书源」即可拉到最新数据
///   3. **离线可用**：拉取成功后写入 Hive `book_sources_cache` box，
///      下次启动直接用缓存，断网也能用
///   4. **失败兜底**：网络失败时若有缓存用缓存，无缓存则返回空列表
///      （App 不会崩，只是没有可用书源）
class RemoteBookSources {
  RemoteBookSources({
    required this.cacheBox,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// GitHub raw URL：直接读取仓库 book_sources/xiu2_sources.json
  ///
  /// 用 main 分支的 raw URL，不用 jsdelivr CDN（CDN 缓存 12h 不利于"立即生效"）。
  /// 用户在中国大陆访问 GitHub raw 较慢时可手动改用镜像（未来扩展）。
  static const String remoteUrl =
      'https://raw.githubusercontent.com/duzou2026/book_reader/main/book_sources/xiu2_sources.json';

  /// Hive 中缓存书源 JSON 字符串的 box。
  ///
  /// Key 固定为 `xiu2_sources`，value 为完整的 JSON 字符串。
  /// 用 JSON 而非逐条存储是为了：
  ///   - 缓存与远程一一对应，刷新逻辑简单
  ///   - 单 key 读写，避免污染用户自己的 book_sources box
  final dynamic /* Box<String> */ cacheBox;

  final Dio _dio;

  /// 缓存 key（写死，方便后续扩展多源订阅）。
  static const String cacheKey = 'xiu2_sources';

  /// 从远程拉取最新书源，写入缓存并返回。
  ///
  /// [forceRefresh]：
  ///   - false（默认）：先尝试缓存，无缓存才联网
  ///   - true：跳过缓存，强制联网拉取最新
  ///
  /// 失败时：
  ///   - 网络错误 / 解析失败 → 回退到缓存（若有）→ 否则返回空列表
  Future<List<BookSource>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readCache();
      if (cached != null) return cached;
    }
    try {
      final response = await _dio.get<dynamic>(
        remoteUrl,
        options: Options(
          responseType: ResponseType.plain,
          // 网络不好时给 15s 超时
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final body = response.data;
      if (body is! String || body.isEmpty) {
        throw FormatException('远程书源响应为空');
      }
      final sources = _parseJson(body);
      await _writeCache(body);
      return sources;
    } catch (e) {
      debugPrint('远程书源拉取失败：$e');
      // 失败回退缓存
      final cached = _readCache();
      if (cached != null) return cached;
      return const [];
    }
  }

  /// 解析 JSON 字符串为 [BookSource] 列表。
  ///
  /// 单条解析失败时跳过，不阻断整体加载（legado 生态字段可能有些扩展，
  /// 我们 model 不支持的会被 freezed 忽略）。
  List<BookSource> _parseJson(String body) {
    final jsonList = jsonDecode(body);
    if (jsonList is! List) {
      throw FormatException(
          '书源 JSON 顶层应为数组，实际为 ${jsonList.runtimeType}');
    }
    final sources = <BookSource>[];
    for (final item in jsonList) {
      if (item is! Map) continue;
      try {
        final source = BookSource.fromJson(item.cast<String, dynamic>());
        sources.add(source);
      } catch (e) {
        debugPrint('跳过解析失败的书源：$e');
      }
    }
    return sources;
  }

  List<BookSource>? _readCache() {
    final cached = cacheBox.get(cacheKey) as String?;
    if (cached == null || cached.isEmpty) return null;
    try {
      return _parseJson(cached);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String jsonBody) async {
    await cacheBox.put(cacheKey, jsonBody);
  }

  /// 清除缓存（用于「设置 → 清除缓存」等场景）。
  Future<void> clearCache() async {
    await cacheBox.delete(cacheKey);
  }
}
