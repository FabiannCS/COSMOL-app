import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_config.dart';
import '../services/storage_service.dart';
import '../services/device_service.dart';
import 'device_interceptor.dart';
import 'auth_interceptor.dart';

final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final deviceService = ref.watch(deviceServiceProvider);

  // Instancia aislada para peticiones de refresh token (evita bucles infinitos en interceptores)
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ),
  );

  return AuthInterceptor(
    storageService: storageService,
    deviceService: deviceService,
    refreshDio: refreshDio,
  );
});

final apiClientProvider = Provider<Dio>((ref) {
  final deviceService = ref.watch(deviceServiceProvider);
  final authInterceptor = ref.watch(authInterceptorProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    DeviceInterceptor(deviceService: deviceService),
    authInterceptor,
    LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ),
  ]);

  return dio;
});
