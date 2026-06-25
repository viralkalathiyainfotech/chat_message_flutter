import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import '../../services/storage_service.dart';
import '../../services/session_privacy_service.dart';
import '../../constants/network_constants.dart';

class AuthInterceptor extends Interceptor {
  final StorageService _storageService = getx.Get.find<StorageService>();
  final Dio _dio;
  bool _isRefreshing = false;

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
    // Only attempt refresh on 401, and only if we have a refresh token
    if (err.response?.statusCode == 401 &&
        _storageService.refreshToken != null &&
        !_isRefreshing) {
      // Prevent infinite loops on the refresh token endpoint itself
      if (err.requestOptions.path.contains(
        NetworkConstants.generateNewTokens,
      )) {
        await _clearPrivateSession();
        getx.Get.offAllNamed('/login');
        return super.onError(err, handler);
      }

      _isRefreshing = true;
      try {
        final newTokens = await _refreshToken(_storageService.refreshToken!);
        if (newTokens != null) {
          await _storageService.saveTokens(
            token: newTokens['token']!,
            refreshToken: newTokens['refreshToken']!,
          );

          // Retry the original failed request with the new access token
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] =
              'Bearer ${newTokens['token']}';

          final response = await _dio.fetch(retryOptions);
          _isRefreshing = false;
          return handler.resolve(response);
        }
      } catch (e) {
        getx.Get.log('Token refresh failed: $e', isError: true);
      } finally {
        _isRefreshing = false;
      }

      // If refresh failed, clear tokens and redirect to login
      await _clearPrivateSession();
      getx.Get.offAllNamed('/login');
    }
    super.onError(err, handler);
  }

  Future<void> _clearPrivateSession() async {
    if (getx.Get.isRegistered<SessionPrivacyService>()) {
      await getx.Get.find<SessionPrivacyService>().clearUserSessionData();
    } else {
      await _storageService.clearUserScopedPreferences();
    }
  }

  Future<Map<String, String>?> _refreshToken(String refreshToken) async {
    try {
      // Use a fresh Dio instance to avoid re-triggering this interceptor
      final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      // Backend reads refresh token from the Authorization header
      refreshDio.options.headers['Authorization'] = 'Bearer $refreshToken';

      final response = await refreshDio.post(
        NetworkConstants.generateNewTokens,
      );

      if (response.statusCode == 200 &&
          response.data['accessToken'] != null &&
          response.data['refreshToken'] != null) {
        // Backend returns 'accessToken' and 'refreshToken'
        return {
          'token': response.data['accessToken'] as String,
          'refreshToken': response.data['refreshToken'] as String,
        };
      }
    } catch (e) {
      getx.Get.log('Refresh token API error: $e', isError: true);
    }
    return null;
  }
}
