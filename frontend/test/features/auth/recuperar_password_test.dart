import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/core/errors/app_exception.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/auth/data/models/otp_models.dart';
import 'package:cosmol_app/features/auth/data/models/recuperar_password_models.dart';
import 'package:cosmol_app/features/auth/data/models/migrar_telefono_models.dart';
import 'package:cosmol_app/features/auth/data/models/register_credentials_model.dart';
import 'package:cosmol_app/features/auth/data/models/verify_socio_response_model.dart';
import 'package:cosmol_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:cosmol_app/features/auth/presentation/providers/recuperar_password_provider.dart';

class FakeRecuperarPasswordAuthRepository implements AuthRepository {
  bool failValidarTitular = false;
  bool failSolicitarOtp = false;
  bool failVerificarOtp = false;
  bool failCambiarPin = false;

  @override
  Future<ValidarTitularResponseModel> validarTitularRecuperacion({
    required String codSocio,
    required String ci,
  }) async {
    if (failValidarTitular || codSocio != '104523' || ci != '8392019') {
      throw const ValidationException(
        message: 'Código de socio o C.I. no coinciden con los registros de COSMOL.',
      );
    }
    return const ValidarTitularResponseModel(
      sessionId: 'session-rec-123456',
      codSocio: '104523',
      nombreTitular: 'JUAN PEREZ ROCHA',
      telefonoEnmascarado: '+591 7*** **384',
      mensaje: 'Titular validado correctamente.',
    );
  }

  @override
  Future<SolicitarOtpRecuperacionResponseModel> solicitarOtpRecuperacion({
    required String sessionId,
    String canal = 'WHATSAPP',
  }) async {
    if (failSolicitarOtp || sessionId != 'session-rec-123456') {
      throw const ValidationException(message: 'Error al enviar código OTP.');
    }
    return SolicitarOtpRecuperacionResponseModel(
      mensaje: 'Código enviado exitosamente.',
      canal: canal,
      telefonoEnmascarado: '+591 7*** **384',
      ttlSegundos: 300,
      debugCodigoOtp: '384920',
    );
  }

  @override
  Future<VerificarOtpRecuperacionResponseModel> verificarOtpRecuperacion({
    required String sessionId,
    required String codigo,
  }) async {
    if (failVerificarOtp || codigo != '384920') {
      throw const ValidationException(message: 'Código de seguridad incorrecto.');
    }
    return const VerificarOtpRecuperacionResponseModel(
      mensaje: 'Código verificado con éxito.',
      tokenRecuperacion: 'token-reset-xyz789',
      codSocio: '104523',
    );
  }

  @override
  Future<CambiarPinRecuperacionResponseModel> cambiarPinRecuperacion({
    required String tokenRecuperacion,
    required String nuevoPin,
  }) async {
    if (failCambiarPin || tokenRecuperacion != 'token-reset-xyz789') {
      throw const ValidationException(message: 'Token de recuperación inválido.');
    }
    return const CambiarPinRecuperacionResponseModel(
      mensaje: 'Contraseña actualizada exitosamente.',
      codSocio: '104523',
    );
  }

  @override
  Future<VerifySocioResponseModel> verificarSocio({
    required String codSocio,
    required String ci,
  }) => throw UnimplementedError();

  @override
  Future<OtpResponseModel> solicitarOtp({
    required String codSocio,
    required String telefono,
    String canal = 'WHATSAPP',
  }) => throw UnimplementedError();

  @override
  Future<VerifyOtpResponseModel> verificarOtp({
    required String telefono,
    required String codigo,
  }) => throw UnimplementedError();

  @override
  Future<RegisterCredentialsResponseModel> establecerPin({
    required RegisterCredentialsRequestModel request,
  }) => throw UnimplementedError();

  @override
  Future<LoginResponseModel> login({
    required String codSocio,
    required String password,
    required String deviceId,
    String modeloDispositivo = 'Mobile Device',
  }) => throw UnimplementedError();

  @override
  Future<MigrarTelefonoIniciarResponseModel> iniciarMigracionTelefono({
    required MigrarTelefonoIniciarRequestModel request,
  }) => throw UnimplementedError();

  @override
  Future<MigrarTelefonoConfirmarResponseModel> confirmarMigracionTelefono({
    required MigrarTelefonoConfirmarRequestModel request,
  }) => throw UnimplementedError();
}

void main() {
  group('Modelos de Recuperación de Contraseña', () {
    test('ValidarTitularResponseModel serializa y deserializa JSON correctamente', () {
      final json = {
        'session_id': 'sess-123',
        'cod_socio': '104523',
        'nombre_titular': 'JUAN PEREZ',
        'telefono_enmascarado': '+591 7*** **384',
        'mensaje': 'Titular validado',
      };

      final model = ValidarTitularResponseModel.fromJson(json);
      expect(model.sessionId, 'sess-123');
      expect(model.codSocio, '104523');
      expect(model.nombreTitular, 'JUAN PEREZ');
      expect(model.telefonoEnmascarado, '+591 7*** **384');
      expect(model.toJson()['session_id'], 'sess-123');
    });

    test('SolicitarOtpRecuperacionResponseModel parsea correctamente', () {
      final json = {
        'mensaje': 'OTP enviado',
        'canal': 'WHATSAPP',
        'telefono_enmascarado': '+591 7*** **384',
        'ttl_segundos': 300,
        'debug_codigo_otp': '123456',
      };

      final model = SolicitarOtpRecuperacionResponseModel.fromJson(json);
      expect(model.mensaje, 'OTP enviado');
      expect(model.canal, 'WHATSAPP');
      expect(model.debugCodigoOtp, '123456');
    });

    test('VerificarOtpRecuperacionResponseModel parsea token de restablecimiento', () {
      final json = {
        'mensaje': 'Verificado',
        'token_recuperacion': 'token-abc',
        'cod_socio': '104523',
      };

      final model = VerificarOtpRecuperacionResponseModel.fromJson(json);
      expect(model.tokenRecuperacion, 'token-abc');
      expect(model.codSocio, '104523');
    });

    test('CambiarPinRecuperacionResponseModel parsea mensaje de éxito', () {
      final json = {
        'mensaje': 'Contraseña restablecida',
        'cod_socio': '104523',
      };

      final model = CambiarPinRecuperacionResponseModel.fromJson(json);
      expect(model.mensaje, 'Contraseña restablecida');
      expect(model.codSocio, '104523');
    });
  });

  group('RecuperarPasswordNotifier - Flujo Completo de 4 Pasos', () {
    late FakeRecuperarPasswordAuthRepository fakeRepo;
    late RecuperarPasswordNotifier notifier;

    setUp(() {
      fakeRepo = FakeRecuperarPasswordAuthRepository();
      notifier = RecuperarPasswordNotifier(fakeRepo);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('Paso 1: validarTitular exitoso avanza a Step 2 y almacena datos de titular', () async {
      final success = await notifier.validarTitular(
        codSocio: '104523',
        ci: '8392019',
      );

      expect(success, true);
      expect(notifier.state.currentStep, 2);
      expect(notifier.state.sessionId, 'session-rec-123456');
      expect(notifier.state.nombreTitular, 'JUAN PEREZ ROCHA');
      expect(notifier.state.telefonoEnmascarado, '+591 7*** **384');
      expect(notifier.state.errorMessage, isNull);
    });

    test('Paso 1: validarTitular fallido con credenciales erróneas mantiene Step 1 con error', () async {
      final success = await notifier.validarTitular(
        codSocio: '999999',
        ci: '0000000',
      );

      expect(success, false);
      expect(notifier.state.currentStep, 1);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('Paso 2: solicitarOtp envía código e inicia Step 3', () async {
      await notifier.validarTitular(codSocio: '104523', ci: '8392019');
      final success = await notifier.solicitarOtp(canal: 'WHATSAPP');

      expect(success, true);
      expect(notifier.state.currentStep, 3);
      expect(notifier.state.otpSent, true);
      expect(notifier.state.canal, 'WHATSAPP');
    });

    test('Paso 3: verificarOtp valida código de 6 dígitos y pasa a Step 4 con token', () async {
      await notifier.validarTitular(codSocio: '104523', ci: '8392019');
      await notifier.solicitarOtp(canal: 'WHATSAPP');

      final success = await notifier.verificarOtp('384920');

      expect(success, true);
      expect(notifier.state.currentStep, 4);
      expect(notifier.state.otpVerified, true);
      expect(notifier.state.tokenRecuperacion, 'token-reset-xyz789');
    });

    test('Paso 3: verificarOtp con código incorrecto falla', () async {
      await notifier.validarTitular(codSocio: '104523', ci: '8392019');
      await notifier.solicitarOtp(canal: 'WHATSAPP');

      final success = await notifier.verificarOtp('000000');

      expect(success, false);
      expect(notifier.state.currentStep, 3);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('Paso 4: cambiarPin actualiza PIN y marca cambioExitoso', () async {
      await notifier.validarTitular(codSocio: '104523', ci: '8392019');
      await notifier.solicitarOtp(canal: 'WHATSAPP');
      await notifier.verificarOtp('384920');

      final success = await notifier.cambiarPin(
        nuevoPin: '4321',
        confirmarPin: '4321',
      );

      expect(success, true);
      expect(notifier.state.cambioExitoso, true);
      expect(notifier.state.errorMessage, isNull);
    });

    test('Paso 4: cambiarPin con discrepancia en confirmación arroja error', () async {
      await notifier.validarTitular(codSocio: '104523', ci: '8392019');
      await notifier.solicitarOtp(canal: 'WHATSAPP');
      await notifier.verificarOtp('384920');

      final success = await notifier.cambiarPin(
        nuevoPin: '4321',
        confirmarPin: '9999',
      );

      expect(success, false);
      expect(notifier.state.cambioExitoso, false);
      expect(notifier.state.errorMessage, 'Las contraseñas no coinciden.');
    });
  });
}
