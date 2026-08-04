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

  /// 远程书源 JSON 镜像地址列表（按优先级排序）。
  ///
  /// 书源文件 `community_sources.json` 由 `scripts/fetch_community_sources.py`
  /// 从 legado 社区书源聚合站（legado.aoaostar.com）拉取并过滤后生成，
  /// 包含 150+ 条纯规则书源（已过滤掉依赖 JS 网络/Java 桥接/音频源等
  /// 本项目不支持的源）。
  ///
  /// 多镜像策略提高首次拉取成功率：
  ///   1. Gitee raw：国内访问稳定快速，无 CDN 缓存延迟
  ///   2. GitHub raw：境外/VPN 用户兜底，Gitee 被墙时可用
  ///   3. jsDelivr CDN：GitHub 镜像加速，国内访问较快但有缓存延迟
  ///
  /// 任一镜像拉取成功即停止，写入缓存后返回。
  static const List<String> remoteUrls = [
    'https://gitee.com/duzou_5aidnf/novel-reader/raw/master/book_sources/community_sources.json',
    'https://raw.githubusercontent.com/duzou2026/book_reader/master/book_sources/community_sources.json',
    'https://cdn.jsdelivr.net/gh/duzou2026/book_reader@master/book_sources/community_sources.json',
  ];

  /// 主镜像地址（兼容旧代码引用，实际拉取走 [remoteUrls] 列表）。
  static const String remoteUrl =
      'https://gitee.com/duzou_5aidnf/novel-reader/raw/master/book_sources/community_sources.json';

  /// Hive 中缓存书源 JSON 字符串的 box（**必须是独立 box**）。
  ///
  /// Key 固定为 `xiu2_sources`，value 为完整的 List JSON 字符串。
  /// 用 JSON 而非逐条存储是为了：
  ///   - 缓存与远程一一对应，刷新逻辑简单
  ///   - 单 key 读写，避免污染用户的书源 box
  ///
  /// **不能**和 [HiveBookSourceRepository] 的 box 共用：
  /// 这里存的是 List JSON，而 repository 期望每个 value 是单个书源（Map），
  /// 混用会导致 repository 的 `getAll()` 遍历到 List 时
  /// `as Map<String, dynamic>` 崩溃。
  final dynamic /* Box<String> */ cacheBox;

  final Dio _dio;

  /// 缓存 key。
  ///
  /// 改名自 `xiu2_sources` 以区分旧书源集，确保升级后拉取新的
  /// community_sources.json 而非复用旧缓存。
  static const String cacheKey = 'community_sources';

  /// 已禁用：根据用户要求，禁止使用公开书源。
  /// 仅使用用户指定的定制书源（见 [recommendedBookSourceJson]）。
  /// 永远返回空列表。
  Future<List<BookSource>> fetch({bool forceRefresh = false}) async {
    return const [];
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
