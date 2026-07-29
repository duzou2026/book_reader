import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:dio/dio.dart';

/// App 更新检查器。
///
/// 优先走 GitHub Releases API（CI 上传稳定，始终有最新版），GitHub 失败时
/// 回退 Gitee Releases API。下载链接通过 gh-proxy 镜像国内加速。
///
/// 之前 Gitee 优先 + GitHub 回退，但 Gitee 跨境上传经常 cancelled，
/// 导致 Gitee 上最新 release 是旧版，App 误判无更新且不回退 GitHub。
/// 现在反转优先级，GitHub 始终可靠。
///
/// - GitHub API：https://docs.github.com/en/rest/releases/releases#get-the-latest-release
/// - Gitee API：https://gitee.com/api/v5/swagger#/getV5ReposOwnerRepoReleasesLatest
class AppUpdateChecker {
  AppUpdateChecker({
    required this.giteeOwner,
    required this.giteeRepo,
    required this.githubOwner,
    required this.githubRepo,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Gitee 仓库 owner/repo（回退源）。
  final String giteeOwner;
  final String giteeRepo;

  /// GitHub 仓库 owner/repo（首选源，CI 上传稳定）。
  final String githubOwner;
  final String githubRepo;

  final Dio _dio;

  /// 拉取最新 release。
  ///
  /// 策略：先查 GitHub（稳定），失败时回退 Gitee。
  Future<AppUpdateInfo> fetchLatestRelease() async {
    // 1. 首选 GitHub（CI 每次都成功上传 Release，始终有最新版）
    try {
      final info = await _fetchGithubLatest();
      if (info.assets.isNotEmpty) return info;
    } catch (_) {
      // GitHub 网络异常（国内偶发），回退 Gitee
    }
    // 2. 回退 Gitee
    return _fetchGiteeLatest();
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
