import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:dio/dio.dart';

/// GitHub Release 信息检查器。
///
/// 通过 GitHub Releases API 拉取最新 release，解析为 [AppUpdateInfo]。
///
/// API 文档：https://docs.github.com/rest/releases/releases#get-the-latest-release
///
/// 不带 token 时每 IP 每小时 60 次限额，对应用更新检查足够。
class AppUpdateChecker {
  AppUpdateChecker({
    required this.owner,
    required this.repo,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String owner;
  final String repo;
  final Dio _dio;

  /// 拉取最新 release（不包括 prerelease / draft）。
  ///
  /// 抛出：
  ///   - [DioException] 网络错误 / 404
  ///   - [FormatException] JSON 结构异常
  Future<AppUpdateInfo> fetchLatestRelease() async {
    final url = 'https://api.github.com/repos/$owner/$repo/releases/latest';
    final response = await _dio.get<dynamic>(
      url,
      options: Options(
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        responseType: ResponseType.json,
        // GitHub API 偶尔会慢，给 10s 超时
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw FormatException('GitHub API 返回非对象：${data.runtimeType}');
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
        // 只关心 APK
        if (!name.toLowerCase().endsWith('.apk')) continue;
        assets.add(ReleaseAsset(
          name: name,
          browserDownloadUrl: url,
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
      publishedAt: (json['published_at'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
      assets: assets,
    );
  }

  String _stripLeadingV(String s) {
    if (s.startsWith('v') || s.startsWith('V')) return s.substring(1);
    return s;
  }
}
