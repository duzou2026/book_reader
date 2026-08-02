import 'package:book_reader/services/app_update/app_update_checker.dart';
import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:book_reader/services/app_update/apk_installer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前 App 的 Gitee 仓库（国内首选更新源）。
///
/// 仓库地址：https://gitee.com/duzou_5aidnf/novel-reader
const String kGiteeOwner = 'duzou_5aidnf';
const String kGiteeRepo = 'novel-reader';

/// GitHub 仓库（回退更新源）。
///
/// CI 上传 APK 到 GitHub Release 始终成功；Gitee 跨境上传经常超时失败，
/// 当 Gitee release 无 APK 资产时回退到 GitHub。
/// 仓库地址：https://github.com/duzou2026/book_reader
const String kGithubOwner = 'duzou2026';
const String kGithubRepo = 'book_reader';

/// 当前 App 的版本号（与 pubspec.yaml 的 version 字段一致，不含 +build）。
///
/// 注意：每次 bump pubspec.yaml 后需要同步更新这里。
/// 未来可改用 `package_info_plus` 自动读取，避免手动同步。
const String kCurrentAppVersion = '0.17.0';

final appUpdateCheckerProvider = Provider<AppUpdateChecker>((ref) {
  return AppUpdateChecker(
    giteeOwner: kGiteeOwner,
    giteeRepo: kGiteeRepo,
    githubOwner: kGithubOwner,
    githubRepo: kGithubRepo,
  );
});

final apkInstallerProvider = Provider<ApkInstaller>((ref) {
  return ApkInstaller();
});

/// 检查更新用例：拉最新 release + 比对版本号，返回更新信息或 null（已是最新）。
class CheckForUpdate {
  final AppUpdateChecker checker;
  final String currentVersion;

  CheckForUpdate({required this.checker, required this.currentVersion});

  /// 返回值：
  ///   - [AppUpdateInfo]：有可用更新
  ///   - null：已是最新版本
  Future<AppUpdateInfo?> call() async {
    final info = await checker.fetchLatestRelease();
    if (info.isNewerThan(currentVersion)) return info;
    return null;
  }
}

final checkForUpdateProvider = Provider<CheckForUpdate>((ref) {
  return CheckForUpdate(
    checker: ref.watch(appUpdateCheckerProvider),
    currentVersion: kCurrentAppVersion,
  );
});
