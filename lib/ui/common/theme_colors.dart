import 'package:flutter/material.dart';

/// 主题感知的颜色辅助方法。
///
/// 替代 `Colors.grey.shade100`、`.shade200`、`.shade500` 等硬编码灰色，
/// 让 UI 在深色模式下也表现正确。
class ThemeColors {
  ThemeColors._();

  /// 次级背景（替代 `Colors.grey.shade100`）。
  /// 浅色：grey.shade100；深色：Color(0xFF242424)。
  static Color surfaceLevel1(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF242424) : Colors.grey.shade100;
  }

  /// 更深的次级背景（替代 `Colors.grey.shade200/300`）。
  static Color surfaceLevel2(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200;
  }

  /// 描边/分隔色（替代 `Colors.grey.shade300`）。
  static Color outline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF424242) : Colors.grey.shade300;
  }

  /// 次级文本（替代 `Colors.grey.shade500`）。
  static Color mutedText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
  }

  /// 信息提示容器（替代 `Colors.blueGrey.shade50`）。
  static Color infoContainer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1B2A2E) : Colors.blueGrey.shade50;
  }

  /// 成功容器（替代 `Colors.green.shade50`）。
  static Color successContainer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1B2E1B) : Colors.green.shade50;
  }

  /// 成功容器边框。
  static Color successBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.green.shade800 : Colors.green.shade200;
  }

  /// 错误容器（替代 `Colors.red.shade50`）。
  static Color errorContainer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2E1B1B) : Colors.red.shade50;
  }

  /// 错误容器边框。
  static Color errorBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.red.shade800 : Colors.red.shade200;
  }

  /// 错误文本（容器内）。
  static Color errorText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.red.shade200 : Colors.red.shade700;
  }

  /// 成功文本（容器内）。
  static Color successText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.green.shade200 : Colors.green.shade700;
  }

  /// 信息提示容器前景文本。
  static Color infoText(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
}
