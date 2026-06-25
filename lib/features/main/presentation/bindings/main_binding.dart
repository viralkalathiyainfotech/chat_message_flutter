import 'package:get/get.dart';
import '../controllers/main_controller.dart';
import '../../../profile/presentation/bindings/profile_binding.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MainController>(() => MainController());
    ProfileBinding().dependencies();
  }
}
