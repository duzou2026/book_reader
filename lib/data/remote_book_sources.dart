import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 远程书源获取器：从 GitHub 仓库拉取**用户定制书源** JSON，并写入 Hive 缓存。
///
/// 重要约定（MEMORY.md）：
/// - 禁止使用 legado 等公开书源
/// - 仅使用用户指定提供的定制书源（存储在仓库 `book_sources/custom_sources.json`）
///
/// 设计目标：
///   1. **不内置到 APK**：书源 JSON 提交到 GitHub 仓库
///   2. **可热更新**：新增/删除书源只需修改 GitHub 上的 JSON 文件，
///      用户在书源管理页点「刷新书源」即可拉到最新数据
///   3. **离线可用**：拉取成功后写入 Hive `book_sources_cache` box，
///      下次启动直接用缓存，断网也能用
///   4. **失败兜底**：网络失败时若有缓存用缓存，无缓存则返回空列表
class RemoteBookSources {
  RemoteBookSources({
    required this.cacheBox,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// 用户定制书源 JSON 镜像地址列表（按优先级排序）。
  ///
  /// 书源文件 `book_sources/custom_sources.json` 存储用户指定的定制书源，
  /// 不再使用 legado 公开书源。
  ///
  /// 多镜像策略提高首次拉取成功率：
  ///   1. Gitee raw：国内访问稳定快速
  ///   2. GitHub raw：境外用户兜底
  ///   3. jsDelivr CDN：GitHub 镜像加速
  ///
  /// 任一镜像拉取成功即停止，写入缓存后返回。
  static const List<String> remoteUrls = [
    'https://gitee.com/duzou_5aidnf/novel-reader/raw/master/book_sources/custom_sources.json',
    'https://raw.githubusercontent.com/duzou2026/book_reader/master/book_sources/custom_sources.json',
    'https://cdn.jsdelivr.net/gh/duzou2026/book_reader@master/book_sources/custom_sources.json',
  ];

  /// 主镜像地址。
  static const String remoteUrl =
      'https://gitee.com/duzou_5aidnf/novel-reader/raw/master/book_sources/custom_sources.json';

  /// Hive 中缓存书源 JSON 字符串的 box（**必须是独立 box**）。
  final dynamic /* Box<String> */ cacheBox;

  final Dio _dio;

  /// 缓存 key（custom_sources，区别于旧的 community_sources）。
  static const String cacheKey = 'custom_sources';

  /// 从远程拉取最新定制书源，写入缓存并返回。
  Future<List<BookSource>> fetch({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readCache();
      if (cached != null) return cached;
    }
    Object? lastError;
    for (final url in remoteUrls) {
      try {
        final response = await _dio.get<dynamic>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        final body = response.data;
        if (body is! String || body.isEmpty) {
          throw FormatException('远程书源响应为空');
        }
        final sources = _parseJson(body);
        if (sources.isEmpty) {
          throw FormatException('远程书源解析为空列表');
        }
        await _writeCache(body);
        return sources;
      } catch (e) {
        lastError = e;
        debugPrint('镜像拉取失败 $url：$e');
      }
    }
    debugPrint('所有镜像拉取均失败：$lastError');
    final cached = _readCache();
    if (cached != null) return cached;
    return const [];
  }

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

  Future<void> clearCache() async {
    await cacheBox.delete(cacheKey);
  }
}
