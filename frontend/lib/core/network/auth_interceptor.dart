import 'package:dio/dio.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';
import '../errors/app_exception.dart';

typedef OnSessionRevoked = void Function();
typedef OnAccountLocked = void Function(int segundosRestantes);
typedef OnUnauthenticated = void Function();

/// Interceptor de seguridad Dio para JWT, renovación silenciosa y gestión de bloqueos.
class AuthInterceptor extends Interceptor {
  final StorageService storageService;
  final DeviceService deviceService;
  final Dio refreshDio;

  OnSessionRevoked? onSessionRevoked;
  OnAccountLocked? onAccountLocked;
  OnUnauthenticated? onUnauthenticated;

  bool _isRefreshing = false;

  AuthInterceptor({
    required this.storageService,
    required this.deviceService,
    required this.refreshDio,
    this.onSessionRevoked,
    this.onAccountLocked,
    this.onUnauthenticated,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Inyectar Access Token si existe
    final token = await storageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    if (response != null) {
      final data = response.data;
      String? errorCode;
      Map<String, dynamic>? errorDetails;

      if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
        final errorMap = data['error'] as Map<String, dynamic>;
        errorCode = errorMap['code'];
        if (errorMap['details'] is Map<String, dynamic>) {
          errorDetails = errorMap['details'] as Map<String, dynamic>;
        }
      }

      // 1. Manejo de Sesión Revocada por Inicio en Nuevo Dispositivo
      if (errorCode == 'SESSION_REVOKED_NEW_DEVICE') {
        await storageService.clearAuthData();
        onSessionRevoked?.call();
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            error: const SessionRevokedException(),
          ),
        );
      }

      // 2. Manejo de Cuenta Bloqueada
      if (errorCode == 'ACCOUNT_LOCKED') {
        final int segundos = (errorDetails?['bloqueado_segundos_restantes'] as num?)?.toInt() ?? 60;
        onAccountLocked?.call(segundos);
        return handler.next(err);
      }

      // 3. Manejo de 401 Unauthorized -> Intento de Renovación Silenciosa de Token
      if (response.statusCode == 401 && !_isRefreshing) {
        final refreshToken = await storageService.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          _isRefreshing = true;
          try {
            final deviceInfo = await deviceService.getDeviceInfo();
            final refreshResponse = await refreshDio.post(
              '/autenticacion/renovar-token',
              data: {
                'refresh_token': refreshToken,
                'device_id': deviceInfo.deviceId,
              },
            );

            if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
              final newAccessToken = refreshResponse.data['access_token'];
              final newRefreshToken = refreshResponse.data['refresh_token'];

              await storageService.saveTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
              );

              _isRefreshing = false;

              // Re-intentar la petición original retenida con el nuevo token
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccessToken';

              final retryResponse = await refreshDio.fetch(opts);
              return handler.resolve(retryResponse);
            }
          } catch (refreshErr) {
            _isRefreshing = false;
            await storageService.clearAuthData();
            onUnauthenticated?.call();
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                response: err.response,
                error: const UnauthorizedException(),
              ),
            );
          }
        } else {
          await storageService.clearAuthData();
          onUnauthenticated?.call();
        }
      }
    }

    handler.next(err);
  }
}
