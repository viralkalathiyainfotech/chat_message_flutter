import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/theme_controller.dart';

class ColorConstants {
  static Color get primaryBlue {
    if (Get.isRegistered<ThemeController>()) {
      return Get.find<ThemeController>().themeColor;
    }
    return const Color(0xFF6366F1);
  }
  static const Color backgroundDarkMode = Color(
    0xFF141414,
  ); // Actually dark background
  static const Color backgroundLightMode = Color(
    0xFFF7F7F7,
  ); // Actually dark background
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white60;
  static const Color inputBackground = Color(0xFF2B2B2B);
  static const Color white = Colors.white;
}
