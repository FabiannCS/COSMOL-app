import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cosmol_app/core/errors/app_exception.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/auth/data/models/migrar_telefono_models.dart';
import 'package:cosmol_app/features/auth/data/models/otp_models.dart';
import 'package:cosmol_app/features/auth/data/models/recuperar_password_models.dart';
import 'package:cosmol_app/features/auth/data/models/register_credentials_model.dart';
import 'package:cosmol_app/features/auth/data/models/verify_socio_response_model.dart';
import 'package:cosmol_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:cosmol_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cosmol_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmol_app/features/auth/presentation/providers/migrar_celular_provider.dart';

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
  Future<void> saveActiveCodSocio(String codSocio) async {
    activeCodSocio = codSocio;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getActiveCodSocio() async => activeCodSocio;

  @override
  Future<void> clearAuthData() async {
    accessToken = null;
    refreshToken = null;
    activeCodSocio = null;
  }

  @override
  Future<String?> getDeviceId() async => deviceId ?? 'test-device';

  @override
  Future<void> saveDeviceId(String deviceId) async {
    this.deviceId = deviceId;
  }

  Future<bool> hasTokens() async => accessToken != null;

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
}

class FakeMigracionAuthRepository implements AuthRepository {
  bool failIniciar = false;
  bool failConfirmar = false;

  @override
  Future<MigrarTelefonoIniciarResponseModel> iniciarMigracionTelefono({
    required MigrarTelefonoIniciarRequestModel request,
  }) async {
    if (failIniciar) {
      throw const ValidationException(message: 'Credenciales de titular incorrectas.');
    }
    return const MigrarTelefonoIniciarResponseModel(
      sessionId: 'sess-migracion-123',
      mensaje: 'Código enviado al nuevo celular',
      ttlSegundos: 300,
      debugCodigoOtp: '654321',
    );
  }

  @override
  Future<MigrarTelefonoConfirmarResponseModel> confirmarMigracionTelefono({
    required MigrarTelefonoConfirmarRequestModel request,
  }) async {
    if (failConfirmar || request.codigoOtp != '654321') {
      throw const ValidationException(message: 'Código OTP incorrecto.');
    }
    return const MigrarTelefonoConfirmarResponseModel(
      mensaje: 'Migración completada con éxito',
      accessToken: 'new-jwt-access-token',
      refreshToken: 'new-jwt-refresh-token',
      tokenType: 'bearer',
      codSocio: '104523',
      nombre: 'JUAN PEREZ ROCHA',
      suministros: [
        SuministroModel(
          id: 'sum-1',
          codSocio: '104523',
          alias: 'Casa Principal',
          rol: 'TITULAR',
          esSuministroPrincipal: true,
        ),
      ],
    );
  }

  @override
  Future<LoginResponseModel> login({required String codSocio, required String password, required String deviceId, String modeloDispositivo = 'Mobile Device'}) => throw UnimplementedError();

  @override
  Future<VerifySocioResponseModel> verificarSocio({required String codSocio, required String ci}) => throw UnimplementedError();

  @override
  Future<OtpResponseModel> solicitarOtp({required String codSocio, required String telefono, String canal = 'WHATSAPP'}) => throw UnimplementedError();

  @override
  Future<VerifyOtpResponseModel> verificarOtp({required String telefono, required String codigo}) => throw UnimplementedError();

  @override
  Future<RegisterCredentialsResponseModel> establecerPin({required RegisterCredentialsRequestModel request}) => throw UnimplementedError();

  @override
  Future<ValidarTitularResponseModel> validarTitularRecuperacion({required String codSocio, required String ci}) => throw UnimplementedError();

  @override
  Future<SolicitarOtpRecuperacionResponseModel> solicitarOtpRecuperacion({required String sessionId, String canal = 'WHATSAPP'}) => throw UnimplementedError();

  @override
  Future<VerificarOtpRecuperacionResponseModel> verificarOtpRecuperacion({required String sessionId, required String codigo}) => throw UnimplementedError();

  @override
  Future<CambiarPinRecuperacionResponseModel> cambiarPinRecuperacion({required String tokenRecuperacion, required String nuevoPin}) => throw UnimplementedError();
}

void main() {
  group('Modelos de Migración de Teléfono', () {
    test('MigrarTelefonoIniciarRequestModel serializa a JSON correctamente', () {
      const request = MigrarTelefonoIniciarRequestModel(
        codSocio: ' 104523 ',
        ci: ' 6245123 ',
        pinActual: ' 1234 ',
        nuevoTelefono: ' 71234567 ',
        canal: 'whatsapp',
      );

      final json = request.toJson();
      expect(json['cod_socio'], '104523');
      expect(json['ci'], '6245123');
      expect(json['pin_actual'], '1234');
      expect(json['nuevo_telefono'], '71234567');
      expect(json['canal'], 'WHATSAPP');
    });

    test('MigrarTelefonoConfirmarResponseModel deserializa y genera LoginResponseModel', () {
      final json = {
        'mensaje': 'Migrado',
        'access_token': 'jwt-access',
        'refresh_token': 'jwt-refresh',
        'token_type': 'bearer',
        'cod_socio': '104523',
        'nombre': 'JUAN PEREZ',
        'suministros': [
          {
            'id': 's1',
            'cod_socio': '104523',
            'alias': 'Hogar',
            'rol': 'TITULAR',
            'es_suministro_principal': true,
          }
        ]
      };

      final response = MigrarTelefonoConfirmarResponseModel.fromJson(json);
      expect(response.accessToken, 'jwt-access');
      expect(response.refreshToken, 'jwt-refresh');
      expect(response.codSocio, '104523');
      expect(response.suministros.length, 1);

      final loginModel = response.toLoginResponseModel();
      expect(loginModel.accessToken, 'jwt-access');
      expect(loginModel.suministros.first.alias, 'Hogar');
    });
  });

  group('MigrarCelularNotifier Flow Tests', () {
    late FakeMigracionAuthRepository fakeRepo;
    late FakeStorageService fakeStorage;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeMigracionAuthRepository();
      fakeStorage = FakeStorageService();

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          storageServiceProvider.overrideWithValue(fakeStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Estado inicial inicia en paso 1 con valores vacíos', () {
      final state = container.read(migrarCelularProvider);
      expect(state.currentStep, 1);
      expect(state.canal, 'WHATSAPP');
      expect(state.isLoading, false);
      expect(state.migracionExitosa, false);
    });

    test('iniciarMigracion valida campos obligatorios', () async {
      final notifier = container.read(migrarCelularProvider.notifier);

      final result1 = await notifier.iniciarMigracion(
        codSocio: '',
        ci: '',
        pinActual: '1234',
        nuevoTelefono: '71234567',
      );
      expect(result1, false);
      expect(container.read(migrarCelularProvider).errorMessage, contains('Código de Socio'));

      final result2 = await notifier.iniciarMigracion(
        codSocio: '104523',
        ci: '6245123',
        pinActual: '',
        nuevoTelefono: '71234567',
      );
      expect(result2, false);
      expect(container.read(migrarCelularProvider).errorMessage, contains('PIN actual'));

      final result3 = await notifier.iniciarMigracion(
        codSocio: '104523',
        ci: '6245123',
        pinActual: '1234',
        nuevoTelefono: '123',
      );
      expect(result3, false);
      expect(container.read(migrarCelularProvider).errorMessage, contains('8 dígitos'));
    });

    test('iniciarMigracion exitoso pasa a paso 2 y guarda sessionId y debug OTP', () async {
      final notifier = container.read(migrarCelularProvider.notifier);

      final success = await notifier.iniciarMigracion(
        codSocio: '104523',
        ci: '6245123',
        pinActual: '1234',
        nuevoTelefono: '71234567',
        canal: 'WHATSAPP',
      );

      expect(success, true);
      final state = container.read(migrarCelularProvider);
      expect(state.currentStep, 2);
      expect(state.sessionId, 'sess-migracion-123');
      expect(state.debugCodigoOtp, '654321');
      expect(state.errorMessage, isNull);
    });

    test('confirmarOtp valida que el código tenga 6 dígitos', () async {
      final notifier = container.read(migrarCelularProvider.notifier);
      await notifier.iniciarMigracion(
        codSocio: '104523',
        ci: '6245123',
        pinActual: '1234',
        nuevoTelefono: '71234567',
      );

      final result = await notifier.confirmarOtp('123');
      expect(result, false);
      expect(container.read(migrarCelularProvider).errorMessage, contains('6 dígitos'));
    });

    test('confirmarOtp exitoso completa migración y autentica la sesión en AuthProvider', () async {
      final notifier = container.read(migrarCelularProvider.notifier);
      await notifier.iniciarMigracion(
        codSocio: '104523',
        ci: '6245123',
        pinActual: '1234',
        nuevoTelefono: '71234567',
      );

      final success = await notifier.confirmarOtp('654321');
      expect(success, true);

      final state = container.read(migrarCelularProvider);
      expect(state.migracionExitosa, true);
      expect(state.errorMessage, isNull);

      // Verificar que authProvider pasó a estado authenticated
      final authState = container.read(authProvider);
      expect(authState.status, AuthStatus.authenticated);
      expect(authState.activeCodSocio, '104523');

      // Verificar que los tokens se guardaron en storage
      expect(fakeStorage.accessToken, 'new-jwt-access-token');
      expect(fakeStorage.refreshToken, 'new-jwt-refresh-token');
      expect(fakeStorage.activeCodSocio, '104523');
    });

    test('volverAlPaso1 resetea estado de OTP al paso 1', () async {
      final notifier = container.read(migrarCelularProvider.notifier);
      await notifier.iniciarMigracion(
        codSocio: '104523',
        ci: '6245123',
        pinActual: '1234',
        nuevoTelefono: '71234567',
      );

      expect(container.read(migrarCelularProvider).currentStep, 2);

      notifier.volverAlPaso1();
      expect(container.read(migrarCelularProvider).currentStep, 1);
      expect(container.read(migrarCelularProvider).sessionId, isNull);
    });
  });
}
