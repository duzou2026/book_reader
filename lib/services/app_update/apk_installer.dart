import 'dart:io';

import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// APK 下载 + 安装服务。
///
/// 下载流程：
///   1. 拿到外部缓存目录作为下载目标
///   2. 用 [Dio] 下载 APK 到本地文件
///   3. 通过 [MethodChannel] 调用原生 `installApk` 方法
///      - Android：用 FileProvider + ACTION_VIEW 触发系统安装器
///      - iOS / 其他平台：抛 [PlatformException]
class ApkInstaller {
  ApkInstaller({Dio? dio, MethodChannel? channel})
      : _dio = dio ?? Dio(),
        _channel = channel ??
            const MethodChannel('com.bookreader.book_reader/installer');

  final Dio _dio;
  final MethodChannel _channel;

  /// 下载指定 [asset] 到本地。
  ///
  /// [onProgress] 回调 (received, total)，total 为 0 时表示无法获取。
  /// 返回下载好的 [File]。
  Future<File> download(
    ReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    // 用 asset.name 作为文件名，方便复用 / 用户排查
    final savePath = '${dir.path}/updates/${asset.name}';
    final file = File(savePath);
    await file.parent.create(recursive: true);

    // 已存在同名文件且大小一致 → 直接复用
    // Gitee API 不返回 size（恒为 0），此时只要文件存在且非空就复用
    if (file.existsSync() &&
        (asset.size <= 0 ? file.lengthSync() > 0 : file.lengthSync() == asset.size)) {
      return file;
    }

    await _dio.download(
      asset.browserDownloadUrl,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        // GitHub release download 不会重定向到登录，直接 follow
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    return file;
  }

  /// 调用原生安装器安装 APK。
  ///
  /// 仅 Android 平台可用。返回 true 表示成功调起安装器
  /// （用户后续需要在系统弹窗中确认安装）。
  Future<bool> install(File apkFile) async {
    if (!Platform.isAndroid) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: '应用内更新仅支持 Android',
      );
    }
    final result = await _channel.invokeMethod<bool>(
      'installApk',
      {'path': apkFile.absolute.path},
    );
    return result ?? false;
  }

  /// 一键下载 + 安装。
  ///
  /// 适用于「立即更新」按钮：下载完直接调起安装器。
  Future<void> downloadAndInstall(
    ReleaseAsset asset, {
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await download(asset, onProgress: onProgress);
    await install(file);
  }
}
