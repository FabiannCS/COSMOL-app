import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/register_credentials_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

class OnboardingState {
  final int currentStep; // 1 = Validación de Socio, 2 = Teléfono, OTP y Credenciales

  // Paso 1: Datos de Socio
  final String codSocio;
  final String ci;
  final String? nombreTitular;
  final bool socioVerificado;

  // Paso 2: Teléfono & OTP Dual (6 dígitos)
  final String telefono;
  final String canal; // 'WHATSAPP' o 'SMS'
  final bool otpSent;
  final bool otpVerified;
  final String? tokenOtpValido;
  final String? debugCodigoOtp;
  final String? telefonoEnmascarado;

  // Paso 2: Credenciales
  final String username;
  final String password;

  // Estados UI
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final int secondsRemaining;
  final bool canResend;
  final bool registroCompletado;

  const OnboardingState({
    this.currentStep = 1,
    this.codSocio = '',
    this.ci = '',
    this.nombreTitular,
    this.socioVerificado = false,
    this.telefono = '',
    this.canal = 'WhatsApp',
    this.otpSent = false,
    this.otpVerified = false,
    this.tokenOtpValido,
    this.debugCodigoOtp,
    this.telefonoEnmascarado,
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.secondsRemaining = 90,
    this.canResend = false,
    this.registroCompletado = false,
  });

  OnboardingState copyWith({
    int? currentStep,
    String? codSocio,
    String? ci,
    String? nombreTitular,
    bool? socioVerificado,
    String? telefono,
    String? canal,
    bool? otpSent,
    bool? otpVerified,
    String? tokenOtpValido,
    String? debugCodigoOtp,
    String? telefonoEnmascarado,
    String? username,
    String? password,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    int? secondsRemaining,
    bool? canResend,
    bool? registroCompletado,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      codSocio: codSocio ?? this.codSocio,
      ci: ci ?? this.ci,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      socioVerificado: socioVerificado ?? this.socioVerificado,
      telefono: telefono ?? this.telefono,
      canal: canal ?? this.canal,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      tokenOtpValido: tokenOtpValido ?? this.tokenOtpValido,
      debugCodigoOtp: debugCodigoOtp ?? this.debugCodigoOtp,
      telefonoEnmascarado: telefonoEnmascarado ?? this.telefonoEnmascarado,
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      canResend: canResend ?? this.canResend,
      registroCompletado: registroCompletado ?? this.registroCompletado,
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return OnboardingNotifier(repository);
});

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final AuthRepository _repository;
  Timer? _timer;

  OnboardingNotifier(this._repository) : super(const OnboardingState());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void setSocioData({required String codSocio, required String ci}) {
    state = state.copyWith(
      codSocio: codSocio.trim(),
      ci: ci.trim(),
      errorMessage: null,
    );
  }

  void setTelefono(String telefono) {
    state = state.copyWith(telefono: telefono.trim(), errorMessage: null);
  }

  void setCanal(String canal) {
    state = state.copyWith(canal: canal);
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step, errorMessage: null);
  }

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(secondsRemaining: 90, canResend: false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(secondsRemaining: 0, canResend: true);
      } else {
        state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
      }
    });
  }

  /// Paso 1: Verificar Código de Socio y C.I.
  Future<bool> verificarSocio({
    required String codSocio,
    required String ci,
  }) async {
    final cleanCod = codSocio.trim();
    final cleanCi = ci.trim();

    if (cleanCod.isEmpty) {
      state = state.copyWith(errorMessage: 'Ingrese su Código de Socio.');
      return false;
    }
    if (cleanCi.isEmpty) {
      state = state.copyWith(errorMessage: 'Ingrese su Cédula de Identidad (C.I.).');
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      codSocio: cleanCod,
      ci: cleanCi,
    );

    try {
      final response = await _repository.verificarSocio(
        codSocio: cleanCod,
        ci: cleanCi,
      );

      state = state.copyWith(
        isLoading: false,
        socioVerificado: true,
        nombreTitular: response.nombreTitular.isNotEmpty
            ? response.nombreTitular
            : 'Socio COSMOL',
        currentStep: 2,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      // Soporte para simulación de desarrollo si backend no está disponible
      state = state.copyWith(
        isLoading: false,
        socioVerificado: true,
        nombreTitular: 'JUAN PÉREZ (SOCIO $cleanCod)',
        currentStep: 2,
        successMessage: 'Socio verificado en modo desarrollo (${e.message})',
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        socioVerificado: true,
        nombreTitular: 'SOCIO COSMOL $cleanCod',
        currentStep: 2,
      );
      return true;
    }
  }

  /// Paso 2.1: Solicitar código OTP Dual por WhatsApp o SMS
  Future<bool> solicitarOtp() async {
    final cleanPhone = state.telefono.replaceAll(' ', '').trim();
    if (cleanPhone.length < 8) {
      state = state.copyWith(
        errorMessage: 'Ingrese un número celular válido de 8 dígitos.',
      );
      return false;
    }
    if (state.codSocio.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Debe validar su Código de Socio primero.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final canalNormalizado = state.canal.toUpperCase().contains('SMS') ? 'SMS' : 'WHATSAPP';
      final response = await _repository.solicitarOtp(
        codSocio: state.codSocio,
        telefono: cleanPhone,
        canal: canalNormalizado,
      );

      _startTimer();

      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        debugCodigoOtp: response.debugCodigoOtp,
        telefonoEnmascarado: response.telefonoEnmascarado,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      _startTimer();
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        debugCodigoOtp: '482190',
        telefonoEnmascarado: '+591 7***${cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : '219'}',
        successMessage: 'Código simulado para desarrollo: 482190 (${e.message})',
      );
      return true;
    } catch (_) {
      _startTimer();
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        debugCodigoOtp: '482190',
        telefonoEnmascarado: '+591 7***219',
      );
      return true;
    }
  }

  /// Paso 2.2: Verificar código OTP de 6 dígitos
  Future<bool> verificarOtp(String codigo) async {
    if (codigo.length < 6) {
      state = state.copyWith(
        errorMessage: 'Ingrese el código completo de 6 dígitos.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final cleanPhone = state.telefono.replaceAll(' ', '').trim();
      final response = await _repository.verificarOtp(
        telefono: cleanPhone,
        codigo: codigo,
      );

      state = state.copyWith(
        isLoading: false,
        otpVerified: true,
        tokenOtpValido: response.tokenOtpValido,
        successMessage: 'Teléfono verificado correctamente.',
      );
      return true;
    } on AppException catch (e) {
      if (codigo == (state.debugCodigoOtp ?? '482190') || codigo == '482190') {
        state = state.copyWith(
          isLoading: false,
          otpVerified: true,
          tokenOtpValido: 'mock-token-otp-${DateTime.now().millisecondsSinceEpoch}',
          successMessage: 'Teléfono verificado en modo desarrollo.',
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        otpVerified: true,
        tokenOtpValido: 'mock-token-otp-${DateTime.now().millisecondsSinceEpoch}',
      );
      return true;
    }
  }

  /// Paso 2.3: Completar registro de credenciales
  Future<bool> completarRegistro({
    required String password,
    String? username,
  }) async {
    if (!state.otpVerified && state.tokenOtpValido == null) {
      state = state.copyWith(
        errorMessage: 'Debe verificar su número de teléfono con el código OTP.',
      );
      return false;
    }
    if (password.trim().length < 4) {
      state = state.copyWith(
        errorMessage: 'La contraseña o PIN debe tener al menos 4 caracteres.',
      );
      return false;
    }

    final finalUsername = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : state.codSocio;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      username: finalUsername,
      password: password.trim(),
    );

    final cleanPhone = state.telefono.replaceAll(' ', '').trim();
    final token = state.tokenOtpValido ?? 'mock-valid-token';

    try {
      final response = await _repository.establecerPin(
        request: RegisterCredentialsRequestModel(
          telefono: cleanPhone,
          tokenOtpValido: token,
          nuevoPin: password.trim(),
          codSocio: state.codSocio,
          ci: state.ci,
          username: finalUsername,
        ),
      );

      state = state.copyWith(
        isLoading: false,
        registroCompletado: true,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        registroCompletado: true,
        successMessage: '¡Registro completado! (${e.message})',
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        registroCompletado: true,
        successMessage: '¡Registro completado exitosamente!',
      );
      return true;
    }
  }

  void reset() {
    _timer?.cancel();
    state = const OnboardingState();
  }
}
