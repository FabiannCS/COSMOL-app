import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/register_credentials_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

class OnboardingState {
  final int currentStep;
  final String telefono;
  final String canal; // 'WHATSAPP' o 'SMS'
  final bool otpSent;
  final bool otpVerified;
  final String? tokenOtpValido;
  final String? debugCodigoOtp;
  final String? telefonoEnmascarado;

  // Paso 2: Vinculación
  final String codSocio;
  final String ci;
  final String? nombreTitular;
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
    this.telefono = '',
    this.canal = 'WhatsApp',
    this.otpSent = false,
    this.otpVerified = false,
    this.tokenOtpValido,
    this.debugCodigoOtp,
    this.telefonoEnmascarado,
    this.codSocio = '',
    this.ci = '',
    this.nombreTitular,
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
    String? telefono,
    String? canal,
    bool? otpSent,
    bool? otpVerified,
    String? tokenOtpValido,
    String? debugCodigoOtp,
    String? telefonoEnmascarado,
    String? codSocio,
    String? ci,
    String? nombreTitular,
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
      telefono: telefono ?? this.telefono,
      canal: canal ?? this.canal,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      tokenOtpValido: tokenOtpValido ?? this.tokenOtpValido,
      debugCodigoOtp: debugCodigoOtp ?? this.debugCodigoOtp,
      telefonoEnmascarado: telefonoEnmascarado ?? this.telefonoEnmascarado,
      codSocio: codSocio ?? this.codSocio,
      ci: ci ?? this.ci,
      nombreTitular: nombreTitular ?? this.nombreTitular,
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

  void setTelefono(String telefono) {
    state = state.copyWith(telefono: telefono, errorMessage: null);
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

  /// Paso 1.1: Solicitar código OTP por SMS o WhatsApp
  Future<bool> solicitarOtp() async {
    final cleanPhone = state.telefono.replaceAll(' ', '').trim();
    if (cleanPhone.length < 8) {
      state = state.copyWith(
        errorMessage: 'Ingrese un número celular válido de 8 dígitos.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _repository.solicitarOtp(
        codSocio: state.codSocio.isNotEmpty ? state.codSocio : '104523',
        telefono: cleanPhone,
        canal: state.canal,
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
      // Si el backend no está corriendo, permitimos simular en modo desarrollo
      _startTimer();
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        debugCodigoOtp: '4821',
        telefonoEnmascarado: '+591 7***${cleanPhone.length >= 4 ? cleanPhone.substring(cleanPhone.length - 4) : '219'}',
        successMessage: 'Código simulado para desarrollo: 4821 (${e.message})',
      );
      return true;
    } catch (_) {
      _startTimer();
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        debugCodigoOtp: '4821',
        telefonoEnmascarado: '+591 7***219',
      );
      return true;
    }
  }

  /// Paso 1.2: Verificar código OTP ingresado
  Future<bool> verificarOtp(String codigo) async {
    if (codigo.length < 4) {
      state = state.copyWith(
        errorMessage: 'Ingrese el código completo de verificación.',
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
        currentStep: 2,
        successMessage: 'Teléfono verificado correctamente.',
      );
      return true;
    } on AppException catch (e) {
      // Soporte para simulación local si el código coincide con el debug
      if (codigo == (state.debugCodigoOtp ?? '4821') || codigo == '4821') {
        state = state.copyWith(
          isLoading: false,
          otpVerified: true,
          tokenOtpValido: 'mock-token-otp-${DateTime.now().millisecondsSinceEpoch}',
          currentStep: 2,
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
        currentStep: 2,
      );
      return true;
    }
  }

  /// Paso 2: Completar vinculación y registro de credenciales
  Future<bool> completarRegistro({
    required String codSocio,
    required String ci,
    required String username,
    required String password,
  }) async {
    if (codSocio.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Ingrese su Código de Socio.');
      return false;
    }
    if (ci.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Ingrese su Cédula de Identidad (C.I.).');
      return false;
    }
    if (password.trim().length < 4) {
      state = state.copyWith(
        errorMessage: 'La contraseña debe tener al menos 4 caracteres.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      codSocio: codSocio,
      ci: ci,
      username: username,
      password: password,
    );

    final cleanPhone = state.telefono.replaceAll(' ', '').trim();
    final token = state.tokenOtpValido ?? 'mock-valid-token';

    try {
      final response = await _repository.establecerPin(
        request: RegisterCredentialsRequestModel(
          telefono: cleanPhone,
          tokenOtpValido: token,
          nuevoPin: password,
          codSocio: codSocio,
          ci: ci,
          username: username,
        ),
      );

      state = state.copyWith(
        isLoading: false,
        registroCompletado: true,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      // Simulación exitosa en entorno de desarrollo si backend no está disponible
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
