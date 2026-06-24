import 'package:get/get.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../services/storage_service.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';

class ProfileController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  final GetCurrentUserProfileUseCase? getCurrentUserProfileUseCase;

  ProfileController({this.getCurrentUserProfileUseCase});

  final Rx<UserRealm?> currentUser = Rx<UserRealm?>(null);
  final RxBool notificationsEnabled = true.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();
    _fetchLatestProfile();
  }

  void _loadInitialData() {
    final userId = _storageService.getUserId();
    if (userId != null && userId.isNotEmpty) {
      currentUser.value = RealmHelper().realm.find<UserRealm>(userId);
    }
    notificationsEnabled.value = _storageService.getBool('notifications_enabled', defaultValue: true);
  }

  Future<void> _fetchLatestProfile() async {
    if (getCurrentUserProfileUseCase == null) return;
    isLoading.value = true;
    final result = await getCurrentUserProfileUseCase!();
    isLoading.value = false;
    result.fold(
      (failure) {
        Get.log('Failed to fetch latest profile: ${failure.message}');
      },
      (user) {
        final existingUser = RealmHelper().realm.find<UserRealm>(user.id);
        final userRealm = UserRealm(
          user.id,
          userName: user.userName ?? existingUser?.userName,
          mobileNumber: user.mobileNumber.isNotEmpty ? user.mobileNumber : existingUser?.mobileNumber,
          photo: user.profilePhoto ?? existingUser?.photo,
          bio: user.bio ?? existingUser?.bio,
          isOnline: existingUser?.isOnline ?? true,
          lastSeen: existingUser?.lastSeen ?? DateTime.now(),
          isGroup: existingUser?.isGroup ?? false,
        );
        RealmHelper().saveUsers([userRealm]);
        currentUser.value = userRealm;
      },
    );
  }

  void toggleNotifications(bool value) {
    notificationsEnabled.value = value;
    _storageService.setBool('notifications_enabled', value);
  }

  void toggleTheme() {
    if (Get.isRegistered<ThemeController>()) {
      Get.find<ThemeController>().toggleTheme();
    }
  }

  Future<void> logout() async {
    await _storageService.clearTokens();
    await _storageService.clearUserScopedPreferences();
    RealmHelper().clearUserScopedData();
    Get.offAllNamed(AppRoutes.login);
  }
}
