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

  AuthNotifier({
    required this.storageService,
    required this.authRepository,
    required this.deviceService,
    required this.authInterceptor,
  }) : super(const AuthState()) {
    _initInterceptorCallbacks();
    checkAuthStatus();
  }

  void _initInterceptorCallbacks() {
    authInterceptor.onAccountLocked = handleAccountLocked;
    authInterceptor.onSessionRevoked = handleSessionRevoked;
    authInterceptor.onUnauthenticated = logout;
  }

  Future<void> checkAuthStatus() async {
    final token = await storageService.getAccessToken();
    final codSocio = await storageService.getActiveCodSocio();

    if (token != null && token.isNotEmpty) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        activeCodSocio: codSocio,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
      );
    }
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
  }

  void setOnboardingRequired() {
    state = state.copyWith(status: AuthStatus.onboardingRequired);
  }
}
