import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/database/realm_helper.dart';
import '../../../../core/database/realm_models.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../services/storage_service.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/usecases/profile_usecases.dart';

class ProfileController extends GetxController {
  final StorageService _storageService = Get.find<StorageService>();
  final GetCurrentUserProfileUseCase? getCurrentUserProfileUseCase;
  EditUserUseCase? editUserUseCase;
  QrLoginUseCase? qrLoginUseCase;
  GetContactUsersUseCase? getContactUsersUseCase;
  AddContactListUseCase? addContactListUseCase;

  ProfileController({
    this.getCurrentUserProfileUseCase,
    this.editUserUseCase,
    this.qrLoginUseCase,
    this.getContactUsersUseCase,
    this.addContactListUseCase,
  });

  final Rx<UserRealm?> currentUser = Rx<UserRealm?>(null);
  final RxBool notificationsEnabled = true.obs;
  final RxBool isLoading = false.obs;

  // Theme state
  final RxString selectedThemeMode = 'Dark'.obs;
  final Rx<Color> selectedThemeColor = const Color(0xFF6B53FF).obs;
  final List<Color> themeColors = [
    const Color(0xFF6B53FF),
    const Color(0xFF2D81FF),
    const Color(0xFF1AD598),
    const Color(0xFFFF5C5C),
    const Color(0xFFFF8A00),
    const Color(0xFFF24E9D),
    const Color(0xFFFFB800),
    const Color(0xFFF69B5C),
    const Color(0xFF8B92A5),
    const Color(0xFF1E283C),
    const Color(0xFFFFFFFF),
    const Color(0xFF22C59B),
  ];

  // Personal Info state
  final TextEditingController nameController = TextEditingController(text: 'Wade Warmen');
  final TextEditingController aboutController = TextEditingController(text: "I'm Here");
  final TextEditingController mobileController = TextEditingController(text: '+91 85320 59232');
  final RxString personalInfoPhoto = ''.obs;
  final RxString selectedImagePath = ''.obs;
  final ImagePicker _picker = ImagePicker();

  // QR Code state
  final RxString activeQrTab = 'My Code'.obs;

  // Invite a Friend state
  final RxList<Map<String, dynamic>> inviteContacts = <Map<String, dynamic>>[
    {'id': '1', 'name': 'Leslie Alexander', 'phone': '+1 234 567 8901', 'avatar': 'https://i.pravatar.cc/150?img=1'},
    {'id': '2', 'name': 'Jerome Bell', 'phone': '+1 234 567 8902', 'avatar': 'https://i.pravatar.cc/150?img=2'},
    {'id': '3', 'name': 'Albert Flores', 'phone': '+1 234 567 8903', 'avatar': 'https://i.pravatar.cc/150?img=3'},
    {'id': '4', 'name': 'Courtney Henry', 'phone': '+1 234 567 8904', 'avatar': 'https://i.pravatar.cc/150?img=4'},
    {'id': '5', 'name': 'Cody Fisher', 'phone': '+1 234 567 8905', 'avatar': 'https://i.pravatar.cc/150?img=5'},
    {'id': '6', 'name': 'Cameron Williamson', 'phone': '+1 234 567 8906', 'avatar': 'https://i.pravatar.cc/150?img=6'},
    {'id': '7', 'name': 'Esther Howard', 'phone': '+1 234 567 8907', 'avatar': 'https://i.pravatar.cc/150?img=7'},
    {'id': '8', 'name': 'Jenny Wilson', 'phone': '+1 234 567 8908', 'avatar': 'https://i.pravatar.cc/150?img=8'},
    {'id': '9', 'name': 'Kathryn Murphy', 'phone': '+1 234 567 8909', 'avatar': 'https://i.pravatar.cc/150?img=9'},
    {'id': '10', 'name': 'Ralph Edwards', 'phone': '+1 234 567 8910', 'avatar': 'https://i.pravatar.cc/150?img=10'},
  ].obs;

  ProfileRepositoryImpl _getRepo() {
    return Get.isRegistered<ProfileRepositoryImpl>()
        ? Get.find<ProfileRepositoryImpl>()
        : Get.put(
            ProfileRepositoryImpl(
              remoteDataSource: Get.isRegistered<ProfileRemoteDataSource>()
                  ? Get.find<ProfileRemoteDataSource>()
                  : Get.put(ProfileRemoteDataSourceImpl()),
            ),
          );
  }

  @override
  void onInit() {
    super.onInit();
    editUserUseCase ??= EditUserUseCase(_getRepo());
    qrLoginUseCase ??= QrLoginUseCase(_getRepo());
    getContactUsersUseCase ??= GetContactUsersUseCase(_getRepo());
    addContactListUseCase ??= AddContactListUseCase(_getRepo());

    _loadInitialData();
    _fetchLatestProfile();
    fetchBackendContacts();
    syncContactsToBackend();
  }

  void _loadInitialData() {
    final userId = _storageService.getUserId();
    if (userId != null && userId.isNotEmpty) {
      currentUser.value = RealmHelper().realm.find<UserRealm>(userId);
      if (currentUser.value != null) {
        nameController.text = currentUser.value!.userName ?? 'Wade Warmen';
        mobileController.text = currentUser.value!.mobileNumber ?? '+91 85320 59232';
        aboutController.text = currentUser.value!.bio ?? "I'm Here";
        personalInfoPhoto.value = currentUser.value!.photo ?? '';
      }
    }
    notificationsEnabled.value = _storageService.getBool(
      'notifications_enabled',
      defaultValue: true,
    );
    selectedThemeMode.value = _storageService.getString('theme_mode') ?? 'Dark';
    final savedColor = int.tryParse(_storageService.getString('theme_color') ?? '');
    if (savedColor != null) {
      selectedThemeColor.value = Color(savedColor);
    }
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
          mobileNumber: user.mobileNumber.isNotEmpty
              ? user.mobileNumber
              : existingUser?.mobileNumber,
          photo: user.profilePhoto ?? existingUser?.photo,
          bio: user.bio ?? existingUser?.bio,
          isOnline: existingUser?.isOnline ?? true,
          lastSeen: existingUser?.lastSeen ?? DateTime.now(),
          isGroup: existingUser?.isGroup ?? false,
        );
        RealmHelper().saveUsers([userRealm]);
        currentUser.value = userRealm;
        nameController.text = userRealm.userName ?? 'Wade Warmen';
        mobileController.text = userRealm.mobileNumber ?? '+91 85320 59232';
        aboutController.text = userRealm.bio ?? "I'm Here";
        personalInfoPhoto.value = userRealm.photo ?? '';
      },
    );
  }

  // Personal Info Methods
  Future<void> pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      selectedImagePath.value = image.path;
    }
  }

  Future<void> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      selectedImagePath.value = image.path;
    }
  }

  Future<void> savePersonalInfo() async {
    final userId = _storageService.getUserId();
    if (userId == null || userId.isEmpty) {
      Get.snackbar('Error', 'User not logged in');
      return;
    }
    isLoading.value = true;
    final result = await editUserUseCase!(
      userId,
      nameController.text,
      aboutController.text,
      selectedImagePath.value.isNotEmpty ? selectedImagePath.value : null,
    );
    isLoading.value = false;
    result.fold(
      (failure) => Get.snackbar('Error', failure.message),
      (_) {
        Get.snackbar('Success', 'Profile updated successfully');
        _fetchLatestProfile();
      },
    );
  }

  // QR Code Methods
  void setActiveQrTab(String tab) {
    activeQrTab.value = tab;
  }

  Future<void> scanQrCode(String qrResult) async {
    isLoading.value = true;
    try {
      final Map<String, dynamic> qrData = jsonDecode(qrResult);
      final deviceInfo = {
        'deviceId': 'flutter_mobile_dev_id',
        'deviceName': 'Flutter Mobile',
        'deviceType': 'Mobile',
      };
      final result = await qrLoginUseCase!(qrData, deviceInfo);
      isLoading.value = false;
      result.fold(
        (failure) => Get.snackbar('Error', failure.message),
        (_) => Get.snackbar('Success', 'QR Login successful!'),
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', 'Invalid QR Code format');
    }
  }

  // Theme Methods
  void updateThemeMode(String mode) {
    selectedThemeMode.value = mode;
    _storageService.saveString('theme_mode', mode);
    if (mode == 'Light') {
      Get.changeThemeMode(ThemeMode.light);
    } else if (mode == 'Dark') {
      Get.changeThemeMode(ThemeMode.dark);
    } else {
      Get.changeThemeMode(ThemeMode.system);
    }
  }

  void updateThemeColor(Color color) {
    selectedThemeColor.value = color;
    _storageService.saveString('theme_color', color.toARGB32().toString());
    if (Get.isRegistered<ThemeController>()) {
      Get.find<ThemeController>().changeThemeColor(color);
    }
  }

  // Contacts Methods
  Future<void> fetchBackendContacts() async {
    final result = await getContactUsersUseCase!();
    result.fold(
      (failure) => Get.log('Failed to fetch contact users: ${failure.message}'),
      (users) {
        if (users.isNotEmpty) {
          final List<Map<String, dynamic>> updated = [];
          for (var u in users) {
            updated.add({
              'id': u['_id'] ?? '',
              'name': u['userName'] ?? 'Unknown',
              'phone': u['mobileNumber'] ?? '',
              'avatar': u['photo'] ?? 'https://i.pravatar.cc/150?img=1',
            });
          }
          inviteContacts.value = updated;
        }
      },
    );
  }

  Future<void> syncContactsToBackend() async {
    final contacts = inviteContacts.map((c) => {
      'id': c['id'],
      'name': c['name'],
      'phone': c['phone'],
      'photoUri': c['avatar'],
    }).toList();
    final result = await addContactListUseCase!(contacts);
    result.fold(
      (failure) => Get.log('Failed to sync contacts: ${failure.message}'),
      (_) => Get.log('Contacts synced successfully'),
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
