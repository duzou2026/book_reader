import 'dart:io';

import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:book_reader/services/app_update/app_update_providers.dart';
import 'package:book_reader/ui/settings/app_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用更新控制器：封装「检查 → 弹窗 → 下载安装」流程。
class AppUpdateController {
  AppUpdateController._();

  /// 主动检查更新（用户在设置页点击「检查更新」时调用）。
  ///
  /// 行为：
  ///   - 总是显示进度指示（即使是最新版本也提示「已是最新」）
  ///   - 出错时显示 SnackBar
  static Future<void> checkManually(BuildContext context, WidgetRef ref) async {
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('应用内更新仅支持 Android 平台')),
      );
      return;
    }
    // 用 SnackBar 显示加载状态
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在检查更新...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
    try {
      final update = await ref.read(checkForUpdateProvider)();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
        return;
      }
      await _showUpdateDialog(context, update, autoTriggered: false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败：$e')),
      );
    }
  }

  /// 启动时静默检查更新（仅在有新版本时弹窗，无新版本不打扰用户）。
  ///
  /// 出错时静默忽略，避免影响 App 启动体验。
  static Future<void> checkOnStartup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!Platform.isAndroid) return;
    try {
      final update = await ref.read(checkForUpdateProvider)();
      if (!context.mounted || update == null) return;
      await _showUpdateDialog(context, update, autoTriggered: true);
    } catch (_) {
      // 静默
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo update, {
    required bool autoTriggered,
  }) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: !autoTriggered,
      builder: (_) => AppUpdateDialog(
        update: update,
        autoTriggered: autoTriggered,
      ),
    );
    // 用户点「查看 Release」→ 复制 URL 到剪贴板（避免引入 url_launcher 依赖）
    if (result == 'open_url' && context.mounted && update.htmlUrl.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Release 链接已复制到剪贴板，可在浏览器打开：\n${update.htmlUrl}'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}
