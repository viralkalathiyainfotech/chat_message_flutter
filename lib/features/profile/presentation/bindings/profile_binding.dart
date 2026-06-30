import 'package:get/get.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/profile_usecases.dart';
import '../controllers/profile_controller.dart';
import '../controllers/privacy_controller.dart';
import '../../../auth/data/datasources/auth_remote_data_source.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    // Data sources
    Get.lazyPut<ProfileRemoteDataSource>(() => ProfileRemoteDataSourceImpl());
    Get.lazyPut<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl());

    // Repositories
    Get.lazyPut<ProfileRepository>(() => ProfileRepositoryImpl(remoteDataSource: Get.find()));
    Get.lazyPut<AuthRepository>(() => AuthRepositoryImpl(Get.find()));

    // Use cases
    Get.lazyPut(() => UpdateUserGroupToJoinUseCase(Get.find()));
    Get.lazyPut(() => UpdateUserProfilePhotoPrivacyUseCase(Get.find()));
    Get.lazyPut(() => BlockUserUseCase(Get.find()));
    Get.lazyPut(() => GetContactUsersUseCase(Get.find()));
    Get.lazyPut(() => AddContactListUseCase(Get.find()));
    Get.lazyPut(() => QrLoginUseCase(Get.find()));
    Get.lazyPut(() => EditUserUseCase(Get.find()));
    Get.lazyPut(() => GetCurrentUserProfileUseCase(Get.find()));

    // Controllers
    Get.lazyPut(() => ProfileController(
      getCurrentUserProfileUseCase: Get.find<GetCurrentUserProfileUseCase>(),
      editUserUseCase: Get.find<EditUserUseCase>(),
      qrLoginUseCase: Get.find<QrLoginUseCase>(),
      getContactUsersUseCase: Get.find<GetContactUsersUseCase>(),
      addContactListUseCase: Get.find<AddContactListUseCase>(),
    ));

    Get.lazyPut(() => PrivacyController(
      updateUserGroupToJoinUseCase: Get.find<UpdateUserGroupToJoinUseCase>(),
      updateUserProfilePhotoPrivacyUseCase: Get.find<UpdateUserProfilePhotoPrivacyUseCase>(),
      blockUserUseCase: Get.find<BlockUserUseCase>(),
    ));
  }
}