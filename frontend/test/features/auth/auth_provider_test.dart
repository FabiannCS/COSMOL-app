import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cosmol_app/core/errors/app_exception.dart';
import 'package:cosmol_app/core/network/auth_interceptor.dart';
import 'package:cosmol_app/core/services/device_service.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/auth/data/models/otp_models.dart';
import 'package:cosmol_app/features/auth/data/models/recuperar_password_models.dart';
import 'package:cosmol_app/features/auth/data/models/migrar_telefono_models.dart';
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

  @override
  Future<void> saveCachedDeuda(String codSocio, Map<String, dynamic> data) async {}

  @override
  Map<String, dynamic>? getCachedDeuda(String codSocio) => null;

  @override
  DateTime? getDeudaSyncTime(String codSocio) => null;

  @override
  Future<void> saveCachedSuministros(List<Map<String, dynamic>> data) async {}

  @override
  List<Map<String, dynamic>>? getCachedSuministros() => null;
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
  bool requireTransfer = false;

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
    if (requireTransfer) {
      return const LoginResponseModel(
        accessToken: '',
        refreshToken: '',
        tokenType: 'bearer',
        suministros: [],
        requiereTransferencia: true,
        sessionTransferId: 'trf-12345',
        dispositivoAnteriorModelo: 'Samsung Galaxy S23',
        telefonoEnmascarado: '+591 7***9384',
        mensaje: 'Sesión activa detectada en otro equipo.',
      );
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

  @override
  Future<ValidarTitularResponseModel> validarTitularRecuperacion({required String codSocio, required String ci}) async {
    throw UnimplementedError();
  }

  @override
  Future<SolicitarOtpRecuperacionResponseModel> solicitarOtpRecuperacion({required String sessionId, String canal = 'WHATSAPP'}) async {
    throw UnimplementedError();
  }

  @override
  Future<VerificarOtpRecuperacionResponseModel> verificarOtpRecuperacion({required String sessionId, required String codigo}) async {
    throw UnimplementedError();
  }

  @override
  Future<CambiarPinRecuperacionResponseModel> cambiarPinRecuperacion({required String tokenRecuperacion, required String nuevoPin}) async {
    throw UnimplementedError();
  }

  @override
  Future<MigrarTelefonoIniciarResponseModel> iniciarMigracionTelefono({required MigrarTelefonoIniciarRequestModel request}) async {
    throw UnimplementedError();
  }

  @override
  Future<MigrarTelefonoConfirmarResponseModel> confirmarMigracionTelefono({required MigrarTelefonoConfirmarRequestModel request}) async {
    throw UnimplementedError();
  }

  @override
  Future<TransferenciaSolicitarOtpResponseModel> solicitarOtpTransferencia({
    required String sessionTransferId,
    String canal = 'WHATSAPP',
  }) async {
    return const TransferenciaSolicitarOtpResponseModel(
      sessionTransferId: 'test-transfer-id',
      mensaje: 'Código enviado',
      telefonoEnmascarado: '+591 7***9384',
      debugCodigoOtp: '123456',
    );
  }

  @override
  Future<LoginResponseModel> confirmarTransferenciaDispositivo({
    required String sessionTransferId,
    required String codigoOtp,
  }) async {
    return const LoginResponseModel(
      accessToken: 'fake-jwt-access-token-transferred',
      refreshToken: 'fake-jwt-refresh-token-transferred',
      tokenType: 'bearer',
      suministros: [],
    );
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

    test('Login detecta requiereTransferencia y activa estado de transferencia', () async {
      fakeRepo.requireTransfer = true;

      final result = await authNotifier.login(codSocio: '104523', password: 'secretpassword');

      expect(result, false);
      expect(authNotifier.state.status, AuthStatus.unauthenticated);
      expect(authNotifier.state.requiereTransferencia, true);
      expect(authNotifier.state.sessionTransferId, 'trf-12345');
      expect(authNotifier.state.dispositivoAnteriorModelo, 'Samsung Galaxy S23');
      expect(authNotifier.state.telefonoEnmascarado, '+591 7***9384');
      // Los tokens no deben guardarse todavía
      expect(fakeStorage.accessToken, isNull);
    });

    test('solicitarOtpTransferencia solicita y actualiza debugCodigoOtp para demo', () async {
      fakeRepo.requireTransfer = true;
      await authNotifier.login(codSocio: '104523', password: 'secretpassword');

      final ok = await authNotifier.solicitarOtpTransferencia(canal: 'WHATSAPP');

      expect(ok, true);
      expect(authNotifier.state.debugCodigoOtp, '123456');
    });

    test('confirmarTransferenciaDispositivo culmina autenticación y guarda tokens', () async {
      fakeRepo.requireTransfer = true;
      await authNotifier.login(codSocio: '104523', password: 'secretpassword');

      final ok = await authNotifier.confirmarTransferenciaDispositivo(
        codSocio: '104523',
        codigoOtp: '123456',
      );

      expect(ok, true);
      expect(authNotifier.state.status, AuthStatus.authenticated);
      expect(authNotifier.state.requiereTransferencia, false);
      expect(authNotifier.state.sessionTransferId, isNull);
      expect(fakeStorage.accessToken, 'fake-jwt-access-token-transferred');
      expect(fakeStorage.activeCodSocio, '104523');
    });

    test('cancelarTransferencia limpia el estado sin alterar credenciales', () async {
      fakeRepo.requireTransfer = true;
      await authNotifier.login(codSocio: '104523', password: 'secretpassword');
      expect(authNotifier.state.requiereTransferencia, true);

      authNotifier.cancelarTransferencia();

      expect(authNotifier.state.requiereTransferencia, false);
      expect(authNotifier.state.sessionTransferId, isNull);
      expect(fakeStorage.accessToken, isNull);
    });
  });
}
