import 'package:flutter/material.dart';
import '../../constants/color_constants.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    fontFamily: 'Inter',
    brightness: Brightness.light,
    scaffoldBackgroundColor: ColorConstants.backgroundLightMode,
    primaryColor: ColorConstants.primaryBlue,
    cardColor: const Color(0xFFFFFFFF),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: ColorConstants.backgroundDarkMode),
      bodyMedium: TextStyle(color: ColorConstants.backgroundDarkMode),
    ),
    iconTheme: const IconThemeData(color: ColorConstants.backgroundDarkMode),
    colorScheme: const ColorScheme.light(
      primary: ColorConstants.primaryBlue,
      surface: Color(0xFFFFFFFF),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      selectedItemColor: ColorConstants.primaryBlue,
      unselectedItemColor: Colors.grey,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ColorConstants.backgroundDarkMode,
    primaryColor: ColorConstants.primaryBlue,
    cardColor: const Color(0xFF1A1A1A),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: ColorConstants.white),
      bodyMedium: TextStyle(color: ColorConstants.white),
    ),
    iconTheme: const IconThemeData(color: ColorConstants.white),
    colorScheme: const ColorScheme.dark(
      primary: ColorConstants.primaryBlue,
      surface: Color(0xFF1A1A1A),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      selectedItemColor: ColorConstants.primaryBlue,
      unselectedItemColor: Colors.grey,
    ),
  );
}
