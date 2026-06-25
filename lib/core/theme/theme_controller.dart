import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/storage_service.dart';

import 'app_theme.dart';

class ThemeController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  final _isDarkMode = false.obs;
  bool get isDarkMode => _isDarkMode.value;

  final Rx<Color> _themeColor = const Color(0xFF6366F1).obs;
  Color get themeColor => _themeColor.value;

  ThemeMode get themeMode =>
      _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  ThemeData get lightTheme => AppTheme.getLightTheme(_themeColor.value);
  ThemeData get darkTheme => AppTheme.getDarkTheme(_themeColor.value);

  @override
  void onInit() {
    super.onInit();
    _loadTheme();
  }

  void _loadTheme() {
    // Check if user has explicitly selected a theme
    final savedTheme = _storageService.isDarkMode;
    if (savedTheme != null) {
      _isDarkMode.value = savedTheme;
    } else {
      // Default to device theme
      final isDeviceDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
      _isDarkMode.value = isDeviceDark;
    }

    final savedColor = _storageService.getString('theme_color');
    if (savedColor != null) {
      final colorVal = int.tryParse(savedColor);
      if (colorVal != null) {
        _themeColor.value = Color(colorVal);
      }
    }
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    _storageService.saveThemeMode(_isDarkMode.value);
    _updateTheme();
  }

  void _updateTheme() {
    Get.changeThemeMode(themeMode);
    Get.changeTheme(isDarkMode ? darkTheme : lightTheme);
  }

  void changeThemeColor(Color color) {
    _themeColor.value = color;
    Get.changeTheme(isDarkMode ? darkTheme : lightTheme);
  }
}
