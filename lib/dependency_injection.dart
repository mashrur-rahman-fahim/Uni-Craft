import 'package:get/get.dart';
import 'package:uni_craft/network_controller.dart';

class DependencyInjection {
  static void init() {
    // Initialize network controller
    Get.put<NetworkController>(NetworkController(), permanent: true);

    // Initialize other controllers here as needed
    print("Dependency injection initialized successfully");
  }
}
