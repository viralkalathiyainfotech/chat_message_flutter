import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl());
    Get.lazyPut<AuthRepository>(() => AuthRepositoryImpl(Get.find()));

    Get.lazyPut(() => SendOtpUseCase(Get.find<AuthRepository>()));
    Get.lazyPut(() => VerifyOtpUseCase(Get.find<AuthRepository>()));
    Get.lazyPut(() => UpdateProfileInfoUseCase(Get.find<AuthRepository>()));
    Get.lazyPut(
      () => GetCurrentUserProfileUseCase(Get.find<AuthRepository>()),
    );

    Get.put(
      AuthController(
        sendOtpUseCase: Get.find<SendOtpUseCase>(),
        verifyOtpUseCase: Get.find<VerifyOtpUseCase>(),
        updateProfileUseCase: Get.find<UpdateProfileInfoUseCase>(),
        getCurrentUserProfileUseCase: Get.find<GetCurrentUserProfileUseCase>(),
      ),
    );
  }
}
