import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cosmol_app/core/errors/app_exception.dart';
import 'package:cosmol_app/core/network/auth_interceptor.dart';
import 'package:cosmol_app/core/services/device_service.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/auth/data/models/otp_models.dart';
import 'package:cosmol_app/features/auth/data/models/register_credentials_model.dart';
import 'package:cosmol_app/features/auth/data/models/verify_socio_response_model.dart';
import 'package:cosmol_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:cosmol_app/features/auth/presentation/providers/auth_provider.dart';

class FakeStorageService implements StorageService {
  String? accessToken;
  String? refreshToken;
  String? activeCodSocio;
  String? deviceId;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> clearAuthData() async {
    accessToken = null;
    refreshToken = null;
    activeCodSocio = null;
  }

  @override
  Future<void> saveActiveCodSocio(String codSocio) async {
    activeCodSocio = codSocio;
  }

  @override
  Future<String?> getActiveCodSocio() async => activeCodSocio;

  @override
  Future<void> saveDeviceId(String deviceId) async {
    this.deviceId = deviceId;
  }

  @override
  Future<String?> getDeviceId() async => deviceId;

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
}

class FakeDeviceService implements DeviceService {
  @override
  Future<DeviceInfoResult> getDeviceInfo() async {
    return DeviceInfoResult(
      deviceId: 'test-uuid-device',
      deviceModel: 'Test Device Model',
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  bool shouldLock = false;
  bool shouldRequireOnboarding = false;
  bool shouldThrowGeneric = false;

  @override
  Future<LoginResponseModel> login({
    required String codSocio,
    required String password,
    required String deviceId,
    String modeloDispositivo = 'Mobile Device',
  }) async {
    if (shouldLock) {
      throw const AccountLockedException(
        message: 'Cuenta bloqueada por 3 intentos',
        segundosRestantes: 180,
      );
    }
    if (shouldRequireOnboarding) {
      throw const OnboardingRequiredException(
        message: 'Debe completar el primer acceso',
      );
    }
    if (shouldThrowGeneric) {
      throw const ValidationException(message: 'Credenciales incorrectas');
    }

    return LoginResponseModel(
      accessToken: 'fake-jwt-access-token',
      refreshToken: 'fake-jwt-refresh-token',
      tokenType: 'bearer',
      suministros: [
        SuministroModel(
          id: 'sum-1',
          codSocio: codSocio,
          alias: 'Casa Central',
          rol: 'TITULAR',
          esSuministroPrincipal: true,
        ),
      ],
    );
  }

  @override
  Future<VerifySocioResponseModel> verificarSocio({required String codSocio, required String ci}) async {
    throw UnimplementedError();
  }

  @override
  Future<OtpResponseModel> solicitarOtp({required String codSocio, required String telefono, String canal = 'WHATSAPP'}) async {
    throw UnimplementedError();
  }

  @override
  Future<VerifyOtpResponseModel> verificarOtp({required String telefono, required String codigo}) async {
    throw UnimplementedError();
  }

  @override
  Future<RegisterCredentialsResponseModel> establecerPin({required RegisterCredentialsRequestModel request}) async {
    throw UnimplementedError();
  }
}

void main() {
  group('AuthNotifier Tests', () {
    late FakeStorageService fakeStorage;
    late FakeDeviceService fakeDevice;
    late FakeAuthRepository fakeRepo;
    late AuthInterceptor fakeInterceptor;
    late AuthNotifier authNotifier;

    setUp(() {
      fakeStorage = FakeStorageService();
      fakeDevice = FakeDeviceService();
      fakeRepo = FakeAuthRepository();
      fakeInterceptor = AuthInterceptor(
        storageService: fakeStorage,
        deviceService: fakeDevice,
        refreshDio: Dio(),
      );
      authNotifier = AuthNotifier(
        storageService: fakeStorage,
        authRepository: fakeRepo,
        deviceService: fakeDevice,
        authInterceptor: fakeInterceptor,
      );
    });

    test('Initial checkAuthStatus sets unauthenticated when no token is present', () async {
      await authNotifier.checkAuthStatus();
      expect(authNotifier.state.status, AuthStatus.unauthenticated);
    });

    test('Login success updates state to authenticated and saves tokens', () async {
      final result = await authNotifier.login(codSocio: '104523', password: 'secretpassword');

      expect(result, true);
      expect(authNotifier.state.status, AuthStatus.authenticated);
      expect(authNotifier.state.activeCodSocio, '104523');
      expect(authNotifier.state.suministros.length, 1);
      expect(fakeStorage.accessToken, 'fake-jwt-access-token');
      expect(fakeStorage.activeCodSocio, '104523');
    });

    test('Login handles AccountLockedException correctly', () async {
      fakeRepo.shouldLock = true;

      final result = await authNotifier.login(codSocio: '104523', password: 'wrongpassword');

      expect(result, false);
      expect(authNotifier.state.status, AuthStatus.locked);
      expect(authNotifier.state.bloqueadoSegundosRestantes, 180);
      expect(authNotifier.state.errorMessage, 'Cuenta bloqueada por 3 intentos');
    });

    test('Login handles OnboardingRequiredException correctly', () async {
      fakeRepo.shouldRequireOnboarding = true;

      final result = await authNotifier.login(codSocio: '104523', password: 'firstpassword');

      expect(result, false);
      expect(authNotifier.state.status, AuthStatus.onboardingRequired);
      expect(authNotifier.state.errorMessage, 'Debe completar el primer acceso');
    });

    test('Logout clears tokens and sets state to unauthenticated', () async {
      await authNotifier.login(codSocio: '104523', password: 'secretpassword');
      expect(authNotifier.state.status, AuthStatus.authenticated);

      await authNotifier.logout();
      expect(authNotifier.state.status, AuthStatus.unauthenticated);
      expect(fakeStorage.accessToken, isNull);
      expect(fakeStorage.activeCodSocio, isNull);
    });
  });
}
