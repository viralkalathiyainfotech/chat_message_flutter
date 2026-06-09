import 'package:flutter/material.dart';
import '../../../../constants/color_constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ColorConstants.backgroundDarkMode,
      body: Center(
        child: Text(
          'LOGO',
          style: TextStyle(
            color: ColorConstants.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
