import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:dio/dio.dart';

/// Gitee Release 信息检查器。
///
/// 通过 Gitee Releases API 拉取最新 release，解析为 [AppUpdateInfo]。
///
/// API 文档：https://gitee.com/api/v5/swagger#/getV5ReposOwnerRepoReleasesLatest
///
/// 公开仓库无需 token，国内访问稳定。
class AppUpdateChecker {
  AppUpdateChecker({
    required this.owner,
    required this.repo,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String owner;
  final String repo;
  final Dio _dio;

  /// 拉取最新 release。
  ///
  /// 抛出：
  ///   - [DioException] 网络错误 / 404
  ///   - [FormatException] JSON 结构异常
  Future<AppUpdateInfo> fetchLatestRelease() async {
    final url =
        'https://gitee.com/api/v5/repos/$owner/$repo/releases/latest';
    final response = await _dio.get<dynamic>(
      url,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Gitee API 返回非对象：${data.runtimeType}');
    }
    return _parseRelease(data.cast<String, dynamic>());
  }

  AppUpdateInfo _parseRelease(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String?) ?? '';
    if (tagName.isEmpty) {
      throw FormatException('Release 缺少 tag_name 字段');
    }
    final assetsRaw = json['assets'];
    final assets = <ReleaseAsset>[];
    if (assetsRaw is List) {
      for (final a in assetsRaw) {
        if (a is! Map) continue;
        final am = a.cast<String, dynamic>();
        final name = (am['name'] as String?) ?? '';
        final url = (am['browser_download_url'] as String?) ?? '';
        if (name.isEmpty || url.isEmpty) continue;
        // 只关心 APK（Gitee 会自动附加 zip/tar.gz 源码包，需过滤）
        if (!name.toLowerCase().endsWith('.apk')) continue;
        assets.add(ReleaseAsset(
          name: name,
          browserDownloadUrl: url,
          // Gitee API 不返回 size / content_type，用 0 / 空串占位
          size: (am['size'] as num?)?.toInt() ?? 0,
          contentType: (am['content_type'] as String?) ?? '',
        ));
      }
    }
    return AppUpdateInfo(
      tagName: tagName,
      version: _stripLeadingV(tagName),
      name: (json['name'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      // Gitee 用 created_at（GitHub 用 published_at）
      publishedAt: (json['created_at'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
      assets: assets,
    );
  }

  String _stripLeadingV(String s) {
    if (s.startsWith('v') || s.startsWith('V')) return s.substring(1);
    return s;
  }
}
