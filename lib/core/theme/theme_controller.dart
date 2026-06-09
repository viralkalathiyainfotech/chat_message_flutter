import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/storage_service.dart';

class ThemeController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  
  final _isDarkMode = false.obs;
  bool get isDarkMode => _isDarkMode.value;

  ThemeMode get themeMode => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

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
      final isDeviceDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
      _isDarkMode.value = isDeviceDark;
    }
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    _storageService.saveThemeMode(_isDarkMode.value);
    _updateTheme();
  }

  void _updateTheme() {
    Get.changeThemeMode(themeMode);
  }
}
