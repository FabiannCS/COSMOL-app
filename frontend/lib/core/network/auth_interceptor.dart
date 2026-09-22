import 'dart:async';
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

  Completer<String?>? _refreshCompleter;

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

      // 3. Manejo de 401 Unauthorized -> Renovación de Token Silenciosa y Encolada
      final isRefreshEndpoint = err.requestOptions.path.contains('/autenticacion/renovar-token');
      if (response.statusCode == 401 && !isRefreshEndpoint) {
        // Si ya hay un refresco en curso por otra petición concurrente, esperar su resultado
        if (_refreshCompleter != null) {
          try {
            final newToken = await _refreshCompleter!.future;
            if (newToken != null && newToken.isNotEmpty) {
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await refreshDio.fetch(opts);
              return handler.resolve(retryResponse);
            } else {
              return handler.reject(err);
            }
          } catch (_) {
            return handler.reject(err);
          }
        }

        // Primer hilo en detectar 401: crea el Completer y ejecuta la renovación
        final completer = Completer<String?>();
        _refreshCompleter = completer;

        final refreshToken = await storageService.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
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
              final newAccessToken = refreshResponse.data['access_token']?.toString();
              final newRefreshToken = refreshResponse.data['refresh_token']?.toString() ?? refreshToken;

              if (newAccessToken != null && newAccessToken.isNotEmpty) {
                await storageService.saveTokens(
                  accessToken: newAccessToken,
                  refreshToken: newRefreshToken,
                );

                completer.complete(newAccessToken);
                _refreshCompleter = null;

                // Re-intentar la petición original retenida con el nuevo token
                final opts = err.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';

                final retryResponse = await refreshDio.fetch(opts);
                return handler.resolve(retryResponse);
              }
            }
            throw Exception('Respuesta de refresco inválida');
          } catch (refreshErr) {
            completer.complete(null);
            _refreshCompleter = null;
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
          completer.complete(null);
          _refreshCompleter = null;
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
      }
    }

    handler.next(err);
  }
}
