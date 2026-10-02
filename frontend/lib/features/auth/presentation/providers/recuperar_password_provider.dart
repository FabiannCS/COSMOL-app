import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

class RecuperarPasswordState {
  final int currentStep; // 1: Validar socio, 2: Canal y OTP, 3: Verificar OTP, 4: Nuevo PIN

  // Paso 1: Datos de Socio y Titular
  final String codSocio;
  final String ci;
  final String? nombreTitular;
  final String? telefonoEnmascarado;
  final String? sessionId;

  // Paso 2 y 3: Canal, Despacho y Verificación de OTP
  final String canal; // 'WHATSAPP' o 'SMS'
  final bool otpSent;
  final bool otpVerified;
  final String? tokenRecuperacion;
  final String? debugCodigoOtp;
  final int secondsRemaining;
  final bool canResend;

  // Paso 4: Credenciales
  final String nuevoPin;
  final String confirmarPin;

  // Estados UI
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool cambioExitoso;

  const RecuperarPasswordState({
    this.currentStep = 1,
    this.codSocio = '',
    this.ci = '',
    this.nombreTitular,
    this.telefonoEnmascarado,
    this.sessionId,
    this.canal = 'WHATSAPP',
    this.otpSent = false,
    this.otpVerified = false,
    this.tokenRecuperacion,
    this.debugCodigoOtp,
    this.secondsRemaining = 90,
    this.canResend = false,
    this.nuevoPin = '',
    this.confirmarPin = '',
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.cambioExitoso = false,
  });

  RecuperarPasswordState copyWith({
    int? currentStep,
    String? codSocio,
    String? ci,
    String? nombreTitular,
    String? telefonoEnmascarado,
    String? sessionId,
    String? canal,
    bool? otpSent,
    bool? otpVerified,
    String? tokenRecuperacion,
    String? debugCodigoOtp,
    int? secondsRemaining,
    bool? canResend,
    String? nuevoPin,
    String? confirmarPin,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool? cambioExitoso,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return RecuperarPasswordState(
      currentStep: currentStep ?? this.currentStep,
      codSocio: codSocio ?? this.codSocio,
      ci: ci ?? this.ci,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      telefonoEnmascarado: telefonoEnmascarado ?? this.telefonoEnmascarado,
      sessionId: sessionId ?? this.sessionId,
      canal: canal ?? this.canal,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      tokenRecuperacion: tokenRecuperacion ?? this.tokenRecuperacion,
      debugCodigoOtp: debugCodigoOtp ?? this.debugCodigoOtp,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      canResend: canResend ?? this.canResend,
      nuevoPin: nuevoPin ?? this.nuevoPin,
      confirmarPin: confirmarPin ?? this.confirmarPin,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      cambioExitoso: cambioExitoso ?? this.cambioExitoso,
    );
  }
}

final recuperarPasswordProvider =
    StateNotifierProvider<RecuperarPasswordNotifier, RecuperarPasswordState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RecuperarPasswordNotifier(repository);
});

class RecuperarPasswordNotifier extends StateNotifier<RecuperarPasswordState> {
  final AuthRepository _repository;
  Timer? _timer;

  RecuperarPasswordNotifier(this._repository) : super(const RecuperarPasswordState());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void setCanal(String canal) {
    if (!mounted) return;
    state = state.copyWith(canal: canal.toUpperCase());
  }

  void setStep(int step) {
    if (!mounted) return;
    state = state.copyWith(currentStep: step, clearError: true);
  }

  void clearError() {
    if (!mounted) return;
    state = state.copyWith(clearError: true);
  }

  void reset() {
    _timer?.cancel();
    if (!mounted) return;
    state = const RecuperarPasswordState();
  }

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(secondsRemaining: 90, canResend: false);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.secondsRemaining > 1) {
        state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
      } else {
        timer.cancel();
        state = state.copyWith(secondsRemaining: 0, canResend: true);
      }
    });
  }

  /// Paso 1: Validar código de socio y CI en backend comercial
  Future<bool> validarTitular({
    required String codSocio,
    required String ci,
  }) async {
    final cleanCod = codSocio.trim();
    final cleanCi = ci.trim();

    if (cleanCod.isEmpty || cleanCi.isEmpty) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Por favor complete todos los campos.',
        isLoading: false,
      );
      return false;
    }

    if (!mounted) return false;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      codSocio: cleanCod,
      ci: cleanCi,
    );

    try {
      final response = await _repository.validarTitularRecuperacion(
        codSocio: cleanCod,
        ci: cleanCi,
      );

      if (!mounted) return true;
      state = state.copyWith(
        isLoading: false,
        sessionId: response.sessionId,
        codSocio: response.codSocio.isNotEmpty ? response.codSocio : cleanCod,
        nombreTitular: response.nombreTitular,
        telefonoEnmascarado: response.telefonoEnmascarado,
        successMessage: response.mensaje,
        currentStep: 2,
      );
      return true;
    } on AppException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo validar el titular. Verifique su conexión.',
      );
      return false;
    }
  }

  /// Paso 2: Solicitar despacho de OTP (WhatsApp / SMS)
  Future<bool> solicitarOtp({String? canal}) async {
    final targetCanal = (canal ?? state.canal).toUpperCase();
    final sessionId = state.sessionId;

    if (sessionId == null || sessionId.isEmpty) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Sesión de recuperación no válida. Inicie nuevamente.',
        isLoading: false,
      );
      return false;
    }

    if (!mounted) return false;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      canal: targetCanal,
    );

    try {
      final response = await _repository.solicitarOtpRecuperacion(
        sessionId: sessionId,
        canal: targetCanal,
      );

      _startTimer();

      if (!mounted) return true;
      state = state.copyWith(
        isLoading: false,
        otpSent: true,
        debugCodigoOtp: response.debugCodigoOtp,
        telefonoEnmascarado: response.telefonoEnmascarado.isNotEmpty
            ? response.telefonoEnmascarado
            : state.telefonoEnmascarado,
        successMessage: response.mensaje,
        currentStep: 3,
      );
      return true;
    } on AppException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo enviar el código OTP. Intente nuevamente.',
      );
      return false;
    }
  }

  /// Reenviar OTP
  Future<bool> reenviarOtp() async {
    if (!state.canResend) return false;
    return await solicitarOtp(canal: state.canal);
  }

  /// Paso 3: Validar código OTP de 6 dígitos
  Future<bool> verificarOtp(String codigo) async {
    final cleanCodigo = codigo.trim();
    final sessionId = state.sessionId;

    if (cleanCodigo.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(cleanCodigo)) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Ingrese el código numérico de 6 dígitos.',
        isLoading: false,
      );
      return false;
    }

    if (sessionId == null || sessionId.isEmpty) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Sesión no válida. Inicie nuevamente.',
        isLoading: false,
      );
      return false;
    }

    if (!mounted) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _repository.verificarOtpRecuperacion(
        sessionId: sessionId,
        codigo: cleanCodigo,
      );

      _timer?.cancel();

      if (!mounted) return true;
      state = state.copyWith(
        isLoading: false,
        otpVerified: true,
        tokenRecuperacion: response.tokenRecuperacion,
        successMessage: response.mensaje,
        currentStep: 4,
      );
      return true;
    } on AppException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al verificar código de seguridad.',
      );
      return false;
    }
  }

  /// Paso 4: Establecer nueva contraseña / PIN
  Future<bool> cambiarPin({
    required String nuevoPin,
    required String confirmarPin,
  }) async {
    final cleanPin = nuevoPin.trim();
    final cleanConfirm = confirmarPin.trim();
    final token = state.tokenRecuperacion;

    if (cleanPin.length < 4) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'El PIN debe contener al menos 4 caracteres.',
        isLoading: false,
      );
      return false;
    }

    if (cleanPin != cleanConfirm) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Las contraseñas no coinciden.',
        isLoading: false,
      );
      return false;
    }

    if (token == null || token.isEmpty) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: 'Token de recuperación no válido o expirado.',
        isLoading: false,
      );
      return false;
    }

    if (!mounted) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _repository.cambiarPinRecuperacion(
        tokenRecuperacion: token,
        nuevoPin: cleanPin,
      );

      if (!mounted) return true;
      state = state.copyWith(
        isLoading: false,
        cambioExitoso: true,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo actualizar la contraseña. Intente nuevamente.',
      );
      return false;
    }
  }
}
