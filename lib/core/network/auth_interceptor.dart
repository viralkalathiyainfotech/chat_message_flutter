import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import '../../services/storage_service.dart';
import '../../constants/network_constants.dart';
class AuthInterceptor extends Interceptor {
  final StorageService _storageService = getx.Get.find<StorageService>();
  final Dio _dio;

  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storageService.token;
    if (token != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && _storageService.refreshToken != null) {
      // Avoid infinite loops if the refresh token call itself fails with 401
      if (err.requestOptions.path == NetworkConstants.generateNewTokens) {
        await _storageService.clearTokens();
        getx.Get.offAllNamed('/login'); // Redirect to login
        return super.onError(err, handler);
      }

      try {
        final newTokens = await _refreshToken(_storageService.refreshToken!);
        if (newTokens != null) {
          await _storageService.saveTokens(
            token: newTokens['token']!,
            refreshToken: newTokens['refreshToken']!,
          );

          // Retry the original request
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer ${_storageService.token}';
          
          final response = await _dio.fetch(options);
          return handler.resolve(response);
        }
      } catch (e) {
        // Refresh token failed, clear storage and go to login
        await _storageService.clearTokens();
        getx.Get.offAllNamed('/login');
      }
    }
    super.onError(err, handler);
  }

  Future<Map<String, String>?> _refreshToken(String refreshToken) async {
    try {
      // Using a separate dio instance to avoid interceptor recursion
      final dio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      dio.options.headers['Authorization'] = 'Bearer $refreshToken'; // As requested by user: authorization send refresh_token
      
      final response = await dio.post(NetworkConstants.generateNewTokens);
      
      if (response.statusCode == 200) {
        return {
          'token': response.data['token'],
          'refreshToken': response.data['refreshToken'],
        };
      }
    } catch (_) {}
    return null;
  }
}
