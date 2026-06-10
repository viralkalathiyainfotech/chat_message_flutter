import 'package:get/get.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../chats/domain/repositories/chat_repository.dart';

class SplashController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();

  @override
  void onInit() {
    super.onInit();
    _checkAuth();
  }

  void _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (_storageService.isLoggedIn) {
      // Trigger contact sync in the background so it's ready for the New Chat screen
      try {
        final chatRepo = Get.find<ChatRepository>();
        chatRepo.syncContacts(); // Fire and forget
      } catch (e) {
        Get.log('Error triggering background contact sync: $e', isError: true);
      }
      
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAllNamed(AppRoutes.onboarding);
    }
  }
}

