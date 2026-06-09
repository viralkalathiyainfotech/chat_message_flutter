import 'package:flutter/material.dart';

/// Extension on num to quickly create SizedBoxes and padding configurations
extension SizeBoxExtension on num {
  Widget get width => SizedBox(width: toDouble());
  Widget get height => SizedBox(height: toDouble());
  Widget get square => SizedBox(height: toDouble(), width: toDouble());
  EdgeInsets get all => EdgeInsets.all(toDouble());
  EdgeInsets get horizontal => EdgeInsets.symmetric(horizontal: toDouble());
  EdgeInsets get vertical => EdgeInsets.symmetric(vertical: toDouble());
}

/// Extension on BuildContext to quickly access MediaQuery, Theme, and layout parameters
extension ContextExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  
  // Navigation shortcut
  void back() => Navigator.of(this).pop();
  
  // Padding shortcuts
  EdgeInsets get viewPadding => MediaQuery.paddingOf(this);
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;
  
  // Theme check
  bool get isDarkMode => theme.brightness == Brightness.dark;
}

/// Extension on String to perform common validations and formatting operations
extension AppStringExtension on String {
  /// Simple email validation check
  bool get isValidEmail {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }

  /// Capitalize first letter of string
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalize the first letter of every word
  String get capitalizeAllWords {
    if (isEmpty) return this;
    return split(' ').map((str) => str.capitalize).join(' ');
  }
}
