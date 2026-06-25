import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/color_constants.dart';
import '../../core/theme/theme_controller.dart';

class AppTheme {
  static ThemeData getLightTheme(Color primaryColor) {
    return ThemeData(
      fontFamily: 'Inter',
      brightness: Brightness.light,
      scaffoldBackgroundColor: ColorConstants.backgroundLightMode,
      primaryColor: primaryColor,
      cardColor: const Color(0xFFFFFFFF),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ColorConstants.backgroundDarkMode),
        bodyMedium: TextStyle(color: ColorConstants.backgroundDarkMode),
      ),
      iconTheme: const IconThemeData(color: ColorConstants.backgroundDarkMode),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        surface: const Color(0xFFFFFFFF),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  static ThemeData getDarkTheme(Color primaryColor) {
    return ThemeData(
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ColorConstants.backgroundDarkMode,
      primaryColor: primaryColor,
      cardColor: const Color(0xFF1A1A1A),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ColorConstants.white),
        bodyMedium: TextStyle(color: ColorConstants.white),
      ),
      iconTheme: const IconThemeData(color: ColorConstants.white),
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        surface: const Color(0xFF1A1A1A),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  static ThemeData get lightTheme =>
    getLightTheme(Get.isRegistered<ThemeController>() ? Get.find<ThemeController>().themeColor : const Color(0xFF6366F1));
  static ThemeData get darkTheme =>
    getDarkTheme(Get.isRegistered<ThemeController>() ? Get.find<ThemeController>().themeColor : const Color(0xFF6366F1));
}
