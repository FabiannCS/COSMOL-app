import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/core/errors/app_exception.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/auth/data/models/otp_models.dart';
import 'package:cosmol_app/features/auth/data/models/register_credentials_model.dart';
import 'package:cosmol_app/features/auth/data/models/verify_socio_response_model.dart';
import 'package:cosmol_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:cosmol_app/features/auth/presentation/providers/onboarding_provider.dart';

class FakeOnboardingAuthRepository implements AuthRepository {
  bool failVerificarSocio = false;
  bool failSolicitarOtp = false;
  bool failVerificarOtp = false;
  bool failEstablecerPin = false;

  @override
  Future<VerifySocioResponseModel> verificarSocio({
    required String codSocio,
    required String ci,
  }) async {
    if (failVerificarSocio) {
      throw const ValidationException(
        message: 'Código de socio o C.I. no coinciden en COSMOL.',
      );
    }
    return VerifySocioResponseModel(
      codSocio: codSocio,
      nombreTitular: 'CARLOS ALBERTO JUSTINIANO',
      mensaje: 'Socio verificado correctamente.',
    );
  }

  @override
  Future<OtpResponseModel> solicitarOtp({
    required String codSocio,
    required String telefono,
    String canal = 'WHATSAPP',
  }) async {
    if (failSolicitarOtp) {
      throw const ValidationException(message: 'Error al enviar OTP.');
    }
    return OtpResponseModel(
      mensaje: 'Código enviado',
      canal: canal,
      ttlSegundos: 300,
      debugCodigoOtp: '482190',
      telefonoEnmascarado: '+591 7***8421',
    );
  }

  @override
  Future<VerifyOtpResponseModel> verificarOtp({
    required String telefono,
    required String codigo,
  }) async {
    if (failVerificarOtp || codigo != '482190') {
      throw const ValidationException(message: 'Código OTP inválido o expirado.');
    }
    return const VerifyOtpResponseModel(
      tokenOtpValido: 'valid-otp-token-12345',
      mensaje: 'OTP verificado correctamente.',
    );
  }

  @override
  Future<RegisterCredentialsResponseModel> establecerPin({
    required RegisterCredentialsRequestModel request,
  }) async {
    if (failEstablecerPin) {
      throw const ValidationException(message: 'Error al establecer PIN.');
    }
    return const RegisterCredentialsResponseModel(
      mensaje: 'Cuenta registrada exitosamente.',
    );
  }

  @override
  Future<LoginResponseModel> login({
    required String codSocio,
    required String password,
    required String deviceId,
    String modeloDispositivo = 'Mobile Device',
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('OnboardingNotifier - Inverted Flow Tests', () {
    late FakeOnboardingAuthRepository fakeRepo;
    late OnboardingNotifier notifier;

    setUp(() {
      fakeRepo = FakeOnboardingAuthRepository();
      notifier = OnboardingNotifier(fakeRepo);
    });

    test('Paso 1: verificarSocio updates state and moves to Step 2', () async {
      final success = await notifier.verificarSocio(
        codSocio: '104523',
        ci: '4829102',
      );

      expect(success, true);
      expect(notifier.state.socioVerificado, true);
      expect(notifier.state.codSocio, '104523');
      expect(notifier.state.ci, '4829102');
      expect(notifier.state.nombreTitular, 'CARLOS ALBERTO JUSTINIANO');
      expect(notifier.state.currentStep, 2);
    });

    test('Paso 2.1: solicitarOtp sends 6-digit OTP and starts timer', () async {
      await notifier.verificarSocio(codSocio: '104523', ci: '4829102');
      notifier.setTelefono('78500000');

      final success = await notifier.solicitarOtp();

      expect(success, true);
      expect(notifier.state.otpSent, true);
      expect(notifier.state.debugCodigoOtp, '482190');
      expect(notifier.state.secondsRemaining, 90);
    });

    test('Paso 2.2: verificarOtp validates 6-digit code', () async {
      await notifier.verificarSocio(codSocio: '104523', ci: '4829102');
      notifier.setTelefono('78500000');
      await notifier.solicitarOtp();

      final success = await notifier.verificarOtp('482190');

      expect(success, true);
      expect(notifier.state.otpVerified, true);
      expect(notifier.state.tokenOtpValido, 'valid-otp-token-12345');
    });

    test('Paso 2.3: completarRegistro creates credentials and completes onboarding', () async {
      await notifier.verificarSocio(codSocio: '104523', ci: '4829102');
      notifier.setTelefono('78500000');
      await notifier.solicitarOtp();
      await notifier.verificarOtp('482190');

      final success = await notifier.completarRegistro(
        password: 'pin12345password',
      );

      expect(success, true);
      expect(notifier.state.registroCompletado, true);
    });
  });
}
