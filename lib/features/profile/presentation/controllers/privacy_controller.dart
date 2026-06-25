import 'package:get/get.dart';
import '../../../../services/storage_service.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/usecases/profile_usecases.dart';

class PrivacyController extends GetxController {
  final UpdateUserGroupToJoinUseCase updateUserGroupToJoinUseCase;
  final UpdateUserProfilePhotoPrivacyUseCase updateUserProfilePhotoPrivacyUseCase;
  BlockUserUseCase? blockUserUseCase;
  final StorageService _storageService = Get.find<StorageService>();

  PrivacyController({
    required this.updateUserGroupToJoinUseCase,
    required this.updateUserProfilePhotoPrivacyUseCase,
    this.blockUserUseCase,
  });

  final RxString groupToJoinPrivacy = 'Everyone'.obs;
  final RxString profilePhotoPrivacy = 'Everyone'.obs;
  final RxBool isLoading = false.obs;

  final RxList<Map<String, String>> blockedContacts = <Map<String, String>>[
    {'id': 'b1', 'name': 'Leslie Alexander', 'phone': '+1 234 567 8901', 'avatar': 'https://i.pravatar.cc/150?img=1'},
    {'id': 'b2', 'name': 'Jerome Bell', 'phone': '+1 234 567 8902', 'avatar': 'https://i.pravatar.cc/150?img=2'},
    {'id': 'b3', 'name': 'Albert Flores', 'phone': '+1 234 567 8903', 'avatar': 'https://i.pravatar.cc/150?img=3'},
    {'id': 'b4', 'name': 'Courtney Henry', 'phone': '+1 234 567 8904', 'avatar': 'https://i.pravatar.cc/150?img=4'},
    {'id': 'b5', 'name': 'Cody Fisher', 'phone': '+1 234 567 8905', 'avatar': 'https://i.pravatar.cc/150?img=5'},
    {'id': 'b6', 'name': 'Cameron Williamson', 'phone': '+1 234 567 8906', 'avatar': 'https://i.pravatar.cc/150?img=6'},
    {'id': 'b7', 'name': 'Esther Howard', 'phone': '+1 234 567 8907', 'avatar': 'https://i.pravatar.cc/150?img=7'},
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
    blockUserUseCase ??= BlockUserUseCase(_getRepo());
    groupToJoinPrivacy.value =
        _storageService.getString('privacy_group_to_join') ?? 'Everyone';
    profilePhotoPrivacy.value =
        _storageService.getString('privacy_profile_photo') ?? 'Everyone';
  }

  Future<void> updateGroupToJoinPrivacy(String value) async {
    isLoading.value = true;
    final result = await updateUserGroupToJoinUseCase(value);
    isLoading.value = false;

    result.fold((failure) => Get.snackbar('Error', failure.message), (_) {
      groupToJoinPrivacy.value = value;
      Get.snackbar('Success', 'Group invitation privacy updated to $value');
    });
  }

  Future<void> updateProfilePhotoPrivacy(String value) async {
    isLoading.value = true;
    final result = await updateUserProfilePhotoPrivacyUseCase(value);
    isLoading.value = false;

    result.fold((failure) => Get.snackbar('Error', failure.message), (_) {
      profilePhotoPrivacy.value = value;
      Get.snackbar('Success', 'Profile photo privacy updated to $value');
    });
  }

  Future<void> unblockContact(String id, String name) async {
    isLoading.value = true;
    final result = await blockUserUseCase!(id);
    isLoading.value = false;

    result.fold(
      (failure) => Get.snackbar('Error', failure.message),
      (_) {
        blockedContacts.removeWhere((contact) => contact['id'] == id);
        Get.snackbar('Success', '$name unblocked successfully');
      },
    );
  }
}
