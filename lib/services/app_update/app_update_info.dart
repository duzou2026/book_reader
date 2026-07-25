import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_update_info.freezed.dart';
part 'app_update_info.g.dart';

/// GitHub Release 中的一条 asset（一个 APK 文件）。
@freezed
class ReleaseAsset with _$ReleaseAsset {
  const factory ReleaseAsset({
    required String name,
    required String browserDownloadUrl,
    required int size,
    @Default('') String contentType,
  }) = _ReleaseAsset;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) =>
      _$ReleaseAssetFromJson(json);
}

/// 从 GitHub Releases API 解析出的最新版本信息。
@freezed
class AppUpdateInfo with _$AppUpdateInfo {
  const factory AppUpdateInfo({
    /// Release tag，如 `v0.2.2`。
    required String tagName,

    /// 解析后的语义版本号（不含 `v` 前缀），如 `0.2.2`。
    required String version,

    /// Release 名称（通常是 commit message）。
    required String name,

    /// Release body（changelog / release notes）。
    @Default('') String body,

    /// Release 发布时间（ISO8601 字符串）。
    @Default('') String publishedAt,

    /// HTML 页面 URL（用户可在浏览器查看）。
    @Default('') String htmlUrl,

    /// 所有可下载的 asset（APK 文件）。
    @Default([]) List<ReleaseAsset> assets,
  }) = _AppUpdateInfo;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) =>
      _$AppUpdateInfoFromJson(json);
}

/// AppUpdateInfo 上的辅助方法。
extension AppUpdateInfoX on AppUpdateInfo {
  /// 是否有可用更新（当前版本 < 此 release 版本时为 true）。
  bool isNewerThan(String currentVersion) {
    return _compareSemver(version, _normalizeSemver(currentVersion)) > 0;
  }

  /// 根据 ABI 名找对应的 APK asset。
  ///
  /// 优先匹配 `arm64-v8a`（现代手机主流），找不到则返回 null。
  ReleaseAsset? assetForAbi(String abi) {
    for (final a in assets) {
      if (a.name.contains('-$abi-') || a.name.contains('-$abi.')) {
        return a;
      }
    }
    return null;
  }

  /// 列出所有 asset 中包含的 ABI（按 release 文件名推断）。
  List<String> get availableAbis {
    const known = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
    return known.where((abi) => assetForAbi(abi) != null).toList();
  }

  /// 格式化版本大小（MB）。
  String sizeLabelFor(ReleaseAsset asset) {
    final mb = asset.size / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// 标准化版本号字符串：去掉 `v` 前缀，去掉 `+build` 后缀。
String _normalizeSemver(String v) {
  var s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  final plusIdx = s.indexOf('+');
  if (plusIdx > 0) s = s.substring(0, plusIdx);
  return s;
}

/// 简单的语义版本比较。
///
/// 返回值：
///   - 正数：a > b
///   - 0：a == b
///   - 负数：a < b
int _compareSemver(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}
