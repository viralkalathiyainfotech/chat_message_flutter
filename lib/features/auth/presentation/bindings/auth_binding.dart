import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/auth_usecases.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl());
    Get.lazyPut<AuthRepositoryImpl>(() => AuthRepositoryImpl(Get.find()));
    
    Get.lazyPut(() => SendOtpUseCase(Get.find<AuthRepositoryImpl>()));
    Get.lazyPut(() => VerifyOtpUseCase(Get.find<AuthRepositoryImpl>()));
    Get.lazyPut(() => UpdateProfileInfoUseCase(Get.find<AuthRepositoryImpl>()));

    Get.put(AuthController(
      sendOtpUseCase: Get.find(),
      verifyOtpUseCase: Get.find(),
      updateProfileUseCase: Get.find(),
    ));
  }
}
