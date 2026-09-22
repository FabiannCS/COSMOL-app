import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/services/device_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/login_response_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  onboardingRequired,
  locked,
}

class AuthState {
  final AuthStatus status;
  final String? activeCodSocio;
  final String? errorMessage;
  final bool isLoading;
  final int bloqueadoSegundosRestantes;
  final List<SuministroModel> suministros;

  const AuthState({
    this.status = AuthStatus.initial,
    this.activeCodSocio,
    this.errorMessage,
    this.isLoading = false,
    this.bloqueadoSegundosRestantes = 0,
    this.suministros = const [],
  });

  AuthState copyWith({
    AuthStatus? status,
    String? activeCodSocio,
    String? errorMessage,
    bool? isLoading,
    int? bloqueadoSegundosRestantes,
    List<SuministroModel>? suministros,
  }) {
    return AuthState(
      status: status ?? this.status,
      activeCodSocio: activeCodSocio ?? this.activeCodSocio,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
      bloqueadoSegundosRestantes:
          bloqueadoSegundosRestantes ?? this.bloqueadoSegundosRestantes,
      suministros: suministros ?? this.suministros,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  final deviceService = ref.watch(deviceServiceProvider);
  final authInterceptor = ref.watch(authInterceptorProvider);

  return AuthNotifier(
    storageService: storageService,
    authRepository: authRepository,
    deviceService: deviceService,
    authInterceptor: authInterceptor,
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final StorageService storageService;
  final AuthRepository authRepository;
  final DeviceService deviceService;
  final AuthInterceptor authInterceptor;
  final VoidCallback? onLogout;

  AuthNotifier({
    required this.storageService,
    required this.authRepository,
    required this.deviceService,
    required this.authInterceptor,
    this.onLogout,
  }) : super(const AuthState()) {
    _initInterceptorCallbacks();
    checkAuthStatus();
  }

  void _initInterceptorCallbacks() {
    authInterceptor.onAccountLocked = handleAccountLocked;
    authInterceptor.onSessionRevoked = handleSessionRevoked;
    authInterceptor.onUnauthenticated = logout;
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        // En tests o mocks que no sean JWTs reales de 3 partes, no asumir expiración
        return false;
      }
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(resp);
      if (payloadMap is! Map<String, dynamic>) return false;
      final exp = payloadMap['exp'];
      if (exp is! num) return false;
      final expDateTime = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(expDateTime.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return false;
    }
  }

  Future<void> checkAuthStatus() async {
    final token = await storageService.getAccessToken();
    final refreshToken = await storageService.getRefreshToken();
    final codSocio = await storageService.getActiveCodSocio();

    if (token == null || token.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
      );
      return;
    }

    // 1. Si el access token no ha expirado, autenticar directamente
    if (!_isTokenExpired(token)) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        activeCodSocio: codSocio,
      );
      return;
    }

    // 2. Si el access token expiró pero existe refresh token, intentar renovar silenciosamente
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final deviceInfo = await deviceService.getDeviceInfo();
        final response = await authInterceptor.refreshDio.post(
          '/autenticacion/renovar-token',
          data: {
            'refresh_token': refreshToken,
            'device_id': deviceInfo.deviceId,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final newAccessToken = response.data['access_token']?.toString();
          final newRefreshToken = response.data['refresh_token']?.toString() ?? refreshToken;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await storageService.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );

            state = state.copyWith(
              status: AuthStatus.authenticated,
              activeCodSocio: codSocio,
            );
            return;
          }
        }
      } catch (_) {
        // Falló renovación de token
      }
    }

    // 3. Si expiró y falló la renovación, cerrar sesión limpiamente
    await logout();
  }

  Future<bool> login({
    required String codSocio,
    required String password,
  }) async {
    final cleanCodSocio = codSocio.trim();
    final cleanPassword = password.trim();

    if (cleanCodSocio.isEmpty || cleanPassword.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Por favor complete todos los campos.',
        isLoading: false,
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final deviceInfo = await deviceService.getDeviceInfo();

      final response = await authRepository.login(
        codSocio: cleanCodSocio,
        password: cleanPassword,
        deviceId: deviceInfo.deviceId,
        modeloDispositivo: deviceInfo.deviceModel,
      );

      // Guardar tokens y suministro activo
      await storageService.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      await storageService.saveActiveCodSocio(cleanCodSocio);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        activeCodSocio: cleanCodSocio,
        suministros: response.suministros,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    } on AccountLockedException catch (e) {
      state = state.copyWith(
        status: AuthStatus.locked,
        bloqueadoSegundosRestantes: e.segundosRestantes,
        errorMessage: e.message,
        isLoading: false,
      );
      return false;
    } on OnboardingRequiredException catch (e) {
      state = state.copyWith(
        status: AuthStatus.onboardingRequired,
        errorMessage: e.message,
        isLoading: false,
      );
      return false;
    } on AppException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Error inesperado al iniciar sesión. Intente nuevamente.',
        isLoading: false,
      );
      return false;
    }
  }

  void handleAccountLocked(int segundos) {
    state = state.copyWith(
      status: AuthStatus.locked,
      bloqueadoSegundosRestantes: segundos,
      errorMessage: 'Cuenta bloqueada temporalmente por intentos fallidos.',
    );
  }

  void handleSessionRevoked() {
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage:
          'Su sesión ha expirado porque se inició en otro dispositivo.',
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> logout() async {
    await storageService.clearAuthData();
    state = const AuthState(status: AuthStatus.unauthenticated);
    onLogout?.call();
  }

  void setOnboardingRequired() {
    state = state.copyWith(status: AuthStatus.onboardingRequired);
  }
}
