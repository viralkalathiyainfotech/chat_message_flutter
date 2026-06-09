import 'package:get/get.dart';
import '../../features/splash/presentation/bindings/splash_binding.dart';
import '../../features/splash/presentation/views/splash_screen.dart';
import '../../features/auth/presentation/bindings/auth_binding.dart';
import '../../features/auth/presentation/views/onboarding_screen.dart';
import '../../features/auth/presentation/views/login_screen.dart';
import '../../features/auth/presentation/views/verify_otp_screen.dart';
import '../../features/auth/presentation/views/profile_info_screen.dart';
import '../../features/main/presentation/bindings/main_binding.dart';
import '../../features/main/presentation/views/main_screen.dart';
import 'app_routes.dart';
class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingScreen(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.verifyOtp,
      page: () => VerifyOtpScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.profileInfo,
      page: () => ProfileInfoScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const MainScreen(),
      binding: MainBinding(),
    ),
  ];
}
