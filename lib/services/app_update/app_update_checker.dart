import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:dio/dio.dart';

/// App 更新检查器。
///
/// 优先走 Gitee Releases API（国内访问快），若 Gitee release 没有 APK 资产
/// （CI 跨境上传 Gitee 经常超时失败）则自动回退到 GitHub Releases API。
///
/// - Gitee API：https://gitee.com/api/v5/swagger#/getV5ReposOwnerRepoReleasesLatest
/// - GitHub API：https://docs.github.com/en/rest/releases/releases#get-the-latest-release
class AppUpdateChecker {
  AppUpdateChecker({
    required this.giteeOwner,
    required this.giteeRepo,
    required this.githubOwner,
    required this.githubRepo,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Gitee 仓库 owner/repo（国内首选源）。
  final String giteeOwner;
  final String giteeRepo;

  /// GitHub 仓库 owner/repo（回退源，APK 始终能上传成功）。
  final String githubOwner;
  final String githubRepo;

  final Dio _dio;

  /// 拉取最新 release。
  ///
  /// 策略：先查 Gitee，若 release 无 APK 资产则回退 GitHub。
  Future<AppUpdateInfo> fetchLatestRelease() async {
    // 1. 先试 Gitee（国内快）
    try {
      final info = await _fetchGiteeLatest();
      if (info.assets.isNotEmpty) return info;
      // Gitee release 存在但没有 APK（上传失败），回退 GitHub
    } catch (_) {
      // Gitee 网络异常 / 404，回退 GitHub
    }
    // 2. 回退 GitHub
    return _fetchGithubLatest();
  }

  Future<AppUpdateInfo> _fetchGiteeLatest() async {
    final url =
        'https://gitee.com/api/v5/repos/$giteeOwner/$giteeRepo/releases/latest';
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
    return _parseGiteeRelease(data.cast<String, dynamic>());
  }

  Future<AppUpdateInfo> _fetchGithubLatest() async {
    final url =
        'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
    final response = await _dio.get<dynamic>(
      url,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/vnd.github+json'},
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw FormatException('GitHub API 返回非对象：${data.runtimeType}');
    }
    return _parseGithubRelease(data.cast<String, dynamic>());
  }

  AppUpdateInfo _parseGiteeRelease(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String?) ?? '';
    if (tagName.isEmpty) {
      throw FormatException('Release 缺少 tag_name 字段');
    }
    return AppUpdateInfo(
      tagName: tagName,
      version: _stripLeadingV(tagName),
      name: (json['name'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      // Gitee 用 created_at
      publishedAt: (json['created_at'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
      assets: _parseAssets(json['assets']),
    );
  }

  AppUpdateInfo _parseGithubRelease(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String?) ?? '';
    if (tagName.isEmpty) {
      throw FormatException('Release 缺少 tag_name 字段');
    }
    return AppUpdateInfo(
      tagName: tagName,
      version: _stripLeadingV(tagName),
      name: (json['name'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      // GitHub 用 published_at
      publishedAt: (json['published_at'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
      assets: _parseAssets(json['assets']),
    );
  }

  List<ReleaseAsset> _parseAssets(dynamic assetsRaw) {
    final assets = <ReleaseAsset>[];
    if (assetsRaw is! List) return assets;
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
        size: (am['size'] as num?)?.toInt() ?? 0,
        contentType: (am['content_type'] as String?) ?? '',
      ));
    }
    return assets;
  }

  String _stripLeadingV(String s) {
    if (s.startsWith('v') || s.startsWith('V')) return s.substring(1);
    return s;
  }
}
