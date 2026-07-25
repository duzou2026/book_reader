import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:book_reader/services/app_update/app_update_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用更新对话框。
///
/// 用法：
/// ```dart
/// final hasUpdate = await showDialog<bool>(
///   context: context,
///   builder: (_) => const AppUpdateDialog(),
/// );
/// ```
///
/// 返回值：
///   - true：用户点击了「立即更新」并完成了下载（安装器已调起）
///   - false / null：用户取消
class AppUpdateDialog extends ConsumerStatefulWidget {
  /// 待安装的更新信息。
  final AppUpdateInfo update;

  /// 是否由启动时自动检查触发（自动触发时若用户取消会更安静，不弹 SnackBar）。
  final bool autoTriggered;

  const AppUpdateDialog({
    super.key,
    required this.update,
    this.autoTriggered = false,
  });

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  /// 当前选中的 ABI（默认 arm64-v8a）。
  String _selectedAbi = 'arm64-v8a';

  /// 下载进度 0..1，null 表示未开始下载。
  double? _progress;

  /// 下载中标识。
  bool _downloading = false;

  /// 错误信息（下载或安装失败时）。
  String? _error;

  @override
  void initState() {
    super.initState();
    // 如果默认 ABI 不在可用列表里，回落到第一个可用的
    final abis = widget.update.availableAbis;
    if (abis.isNotEmpty && !abis.contains(_selectedAbi)) {
      _selectedAbi = abis.first;
    }
  }

  Future<void> _startUpdate() async {
    if (_downloading) return;
    final asset = widget.update.assetForAbi(_selectedAbi);
    if (asset == null) {
      setState(() => _error = '找不到 $_selectedAbi 对应的 APK');
      return;
    }
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final installer = ref.read(apkInstallerProvider);
      await installer.downloadAndInstall(asset, onProgress: (r, t) {
        if (!mounted || t == 0) return;
        setState(() => _progress = r / t);
      });
      if (!mounted) return;
      // 安装器已调起，关闭对话框
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _downloading = false;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final abis = update.availableAbis;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.teal),
          const SizedBox(width: 8),
          Text('发现新版本 v${update.version}',
              style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.publishedAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '发布于 ${_formatDate(update.publishedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            // Release notes
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                child: Text(
                  update.body.isEmpty
                      ? '（本次发布未填写更新说明）'
                      : update.body,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ABI 选择
            if (abis.isNotEmpty) ...[
              Text('选择架构（不知道选哪个就用 arm64-v8a）：',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: abis.map((abi) {
                  final asset = update.assetForAbi(abi);
                  final label = asset != null
                      ? '$abi · ${update.sizeLabelFor(asset)}'
                      : abi;
                  return ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: _selectedAbi == abi,
                    onSelected: _downloading
                        ? null
                        : (_) => setState(() => _selectedAbi = abi),
                  );
                }).toList(),
              ),
            ],
            // 下载进度
            if (_downloading && _progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                '下载中 ${(_progress! * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (update.htmlUrl.isNotEmpty)
          TextButton(
            onPressed: _downloading
                ? null
                : () {
                    // 关闭对话框后让外层跳浏览器查看 release
                    Navigator.of(context).pop('open_url');
                  },
            child: const Text('查看 Release'),
          ),
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(false),
          child: const Text('稍后再说'),
        ),
        FilledButton.icon(
          onPressed: _downloading ? null : _startUpdate,
          icon: const Icon(Icons.download, size: 18),
          label: Text(_downloading ? '下载中...' : '立即更新'),
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
