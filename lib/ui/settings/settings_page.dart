import 'package:book_reader/app/providers.dart';
import 'package:book_reader/services/app_update/app_update_providers.dart';
import 'package:book_reader/services/preferences/theme_prefs_repository.dart';
import 'package:book_reader/ui/settings/app_update_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App 设置页：主题模式、主题色等全局偏好。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePrefsProvider);
    final notifier = ref.read(themePrefsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _SectionHeader(title: '外观'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('主题模式'),
            subtitle: Text(_themeModeLabel(prefs.mode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeModeSheet(context, prefs.mode, notifier),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('主题色'),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _presetColors)
                  GestureDetector(
                    onTap: () => notifier.setSeedColor(c.value),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: prefs.seedColor == c.value
                            ? Border.all(color: Colors.black87, width: 2)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {},
          ),
          const Divider(),
          _SectionHeader(title: '更新'),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: const Text('从 GitHub Release 拉取最新版本'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppUpdateController.checkManually(context, ref),
          ),
          const Divider(),
          _SectionHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('应用版本'),
            subtitle: Text(kCurrentAppVersion),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('开源协议'),
            subtitle: const Text('MIT'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('MIT License')),
              );
            },
          ),
        ],
      ),
    );
  }

  String _themeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.dark:
        return '深色';
    }
  }

  void _showThemeModeSheet(
    BuildContext context,
    AppThemeMode current,
    ThemePrefsNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('选择主题模式',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              for (final m in AppThemeMode.values)
                RadioListTile<AppThemeMode>(
                  value: m,
                  groupValue: current,
                  title: Text(_themeModeLabel(m)),
                  onChanged: (v) {
                    if (v == null) return;
                    notifier.setMode(v);
                    Navigator.of(ctx).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

const List<Color> _presetColors = [
  Color(0xFF00897B), // teal
  Color(0xFF1976D2), // blue
  Color(0xFFE64A19), // deep orange
  Color(0xFF7B1FA2), // purple
  Color(0xFF388E3C), // green
  Color(0xFFC2185B), // pink
  Color(0xFF5D4037), // brown
  Color(0xFF455A64), // blue grey
];
