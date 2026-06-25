import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;

  RetryInterceptor({required this.dio, this.maxRetries = 2});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only retry for network/timeout errors, not 400s or 401s (which are handled by AuthInterceptor)
    if (_shouldRetry(err)) {
      int retryCount = err.requestOptions.extra['retryCount'] ?? 0;

      if (retryCount < maxRetries) {
        err.requestOptions.extra['retryCount'] = retryCount + 1;

        try {
          // Wait a bit before retrying
          await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));

          final response = await dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          if (e is DioException) {
            return onError(e, handler);
          }
        }
      }
    }
    super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}
