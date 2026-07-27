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

    // 下载源优先级（国内访问速度从快到慢）：
    //   1. ghfast.top 镜像 GitHub Release（国内 CDN 加速，实测 6 秒下 25MB）
    //   2. 原始 GitHub release URL（兜底，国内通常很慢或超时）
    // Gitee release 经常因跨境上传超时失败而拿不到 APK，不能作为可靠源。
    final urls = _buildDownloadUrls(asset.browserDownloadUrl);
    Object? lastError;
    for (final url in urls) {
      try {
        await _dio.download(
          url,
          savePath,
          onReceiveProgress: onProgress,
          options: Options(
            followRedirects: true,
            // 单源超时设短一点，失败快速切下一个源
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(minutes: 5),
          ),
        );
        // 下载成功后校验大小（如果已知 size）
        if (asset.size > 0 && file.existsSync() && file.lengthSync() != asset.size) {
          // 大小不一致，可能是被截断，删了重试用下一个源
          await file.delete();
          continue;
        }
        return file;
      } catch (e) {
        lastError = e;
        // 当前源失败，删除可能残留的半成品文件，尝试下一个源
        if (file.existsSync()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        continue;
      }
    }
    throw Exception('所有下载源均失败: $lastError');
  }

  /// 构造下载源 URL 列表（按优先级排序）。
  ///
  /// GitHub Release 原始 URL 国内访问极慢或超时，前面加国内可达的镜像前缀。
  /// 镜像失败时自动回退到原始 URL 兜底。
  List<String> _buildDownloadUrls(String originalUrl) {
    final urls = <String>[];
    // 仅对 github.com 的 release 下载做镜像加速
    if (originalUrl.contains('github.com') &&
        originalUrl.contains('/releases/download/')) {
      // ghfast.top: 国内访问稳定的 GitHub 加速代理，前缀拼接方式
      urls.add('https://ghfast.top/$originalUrl');
    }
    // 原始 URL 作为兜底（Gitee / 其他源直接用原 URL）
    urls.add(originalUrl);
    return urls;
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
