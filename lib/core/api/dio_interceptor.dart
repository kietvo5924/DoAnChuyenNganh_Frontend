import 'package:dio/dio.dart';
import 'package:planmate_app/core/services/session_invalidation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioInterceptor extends Interceptor {
  final SharedPreferences sharedPreferences;
  final SessionInvalidationService sessionInvalidationService;

  DioInterceptor({
    required this.sharedPreferences,
    required this.sessionInvalidationService,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = sharedPreferences.getString('auth_token');

    if (token != null && token.isNotEmpty && !_isAuthEndpoint(options)) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      // Avoid accidentally sending a stale token to auth endpoints.
      options.headers.remove('Authorization');
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      final status = err.response?.statusCode;
      final hadToken = sessionInvalidationService.hasAuthToken;

      if (_isAuthEndpoint(err.requestOptions)) {
        super.onError(err, handler);
        return;
      }

      // Only force logout when user was already authenticated.
      // This prevents breaking SignIn (wrong password -> 401) flows.
      if (hadToken && (status == 401 || status == 302)) {
        final msg = _extractMessage(err.response?.data);
        sessionInvalidationService.forceLogout(
          reason:
              msg ??
              'Tài khoản của bạn đã bị khóa hoặc phiên đăng nhập đã hết hạn.',
        );
      }
    } catch (_) {
      // never block error propagation
    }

    super.onError(err, handler);
  }

  bool _isAuthEndpoint(RequestOptions options) {
    // When using absolute URLs, use uri.path (e.g. /api/auth/signin).
    final path = options.uri.path;
    return path.startsWith('/api/auth/');
  }

  String? _extractMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) return m;
    }
    return null;
  }
}
