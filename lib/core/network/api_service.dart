import 'package:chat_app/core/network/auth_interceptor.dart';
import 'package:chat_app/core/network/retry_interceptor.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../constants/network_constants.dart';

class ApiService extends GetxService {
  late final Dio dio;

  Future<ApiService> init() async {
    dio = Dio(
      BaseOptions(
        baseUrl: NetworkConstants
            .baseUrl, // Common localhost alias for Android Emulator
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          "X-Tunnel-Skip-Anti-Phishing-Page": "true",
          "bypass-tunnel-reminder": "true",
        },
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(dio),
      RetryInterceptor(dio: dio, maxRetries: 2),
      LogInterceptor(
        responseBody: true,
        requestBody: true,
      ), // Useful for debugging
    ]);

    return this;
  }
}
