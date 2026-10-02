import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/migrar_telefono_models.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_provider.dart';

class MigrarCelularState {
  final int currentStep; // 1 = Credenciales y nuevo número, 2 = Código OTP
  final String codSocio;
  final String ci;
  final String? nombreTitular;
  final String pinActual;
  final String nuevoTelefono;
  final String canal; // 'WHATSAPP' o 'SMS'
  final String? sessionId;
  final String? debugCodigoOtp;
  final int secondsRemaining;
  final bool canResend;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final bool migracionExitosa;

  const MigrarCelularState({
    this.currentStep = 1,
    this.codSocio = '',
    this.ci = '',
    this.nombreTitular,
    this.pinActual = '',
    this.nuevoTelefono = '',
    this.canal = 'WHATSAPP',
    this.sessionId,
    this.debugCodigoOtp,
    this.secondsRemaining = 90,
    this.canResend = false,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.migracionExitosa = false,
  });

  MigrarCelularState copyWith({
    int? currentStep,
    String? codSocio,
    String? ci,
    String? nombreTitular,
    String? pinActual,
    String? nuevoTelefono,
    String? canal,
    String? sessionId,
    String? debugCodigoOtp,
    int? secondsRemaining,
    bool? canResend,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool? migracionExitosa,
  }) {
    return MigrarCelularState(
      currentStep: currentStep ?? this.currentStep,
      codSocio: codSocio ?? this.codSocio,
      ci: ci ?? this.ci,
      nombreTitular: nombreTitular ?? this.nombreTitular,
      pinActual: pinActual ?? this.pinActual,
      nuevoTelefono: nuevoTelefono ?? this.nuevoTelefono,
      canal: canal ?? this.canal,
      sessionId: sessionId ?? this.sessionId,
      debugCodigoOtp: debugCodigoOtp ?? this.debugCodigoOtp,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      canResend: canResend ?? this.canResend,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      migracionExitosa: migracionExitosa ?? this.migracionExitosa,
    );
  }
}

class MigrarCelularNotifier extends StateNotifier<MigrarCelularState> {
  final AuthRepository _repository;
  final Ref _ref;
  Timer? _timer;

  MigrarCelularNotifier(this._repository, this._ref)
      : super(const MigrarCelularState());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void inicializar({String? codSocio, String? ci, String? nombreTitular}) {
    state = state.copyWith(
      codSocio: codSocio ?? state.codSocio,
      ci: ci ?? state.ci,
      nombreTitular: nombreTitular ?? state.nombreTitular,
      errorMessage: null,
    );
  }

  void setCanal(String canal) {
    state = state.copyWith(canal: canal);
  }

  void _startTimer({int duration = 90}) {
    _timer?.cancel();
    state = state.copyWith(secondsRemaining: duration, canResend: false);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(secondsRemaining: 0, canResend: true);
      } else {
        state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
      }
    });
  }

  Future<bool> iniciarMigracion({
    required String codSocio,
    required String ci,
    required String pinActual,
    required String nuevoTelefono,
    String? canal,
  }) async {
    final cleanCod = codSocio.trim();
    final cleanCi = ci.trim();
    final cleanPin = pinActual.trim();
    final cleanPhone = nuevoTelefono.replaceAll(' ', '').trim();
    final selectedCanal = canal ?? state.canal;

    if (cleanCod.isEmpty || cleanCi.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Ingrese su Código de Socio y C.I.',
      );
      return false;
    }
    if (cleanPin.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Ingrese su Contraseña o PIN actual.',
      );
      return false;
    }
    if (cleanPhone.length < 8) {
      state = state.copyWith(
        errorMessage: 'Ingrese un número celular nuevo válido (8 dígitos).',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      codSocio: cleanCod,
      ci: cleanCi,
      pinActual: cleanPin,
      nuevoTelefono: cleanPhone,
      canal: selectedCanal,
    );

    try {
      final canalNormalizado =
          selectedCanal.toUpperCase().contains('SMS') ? 'SMS' : 'WHATSAPP';

      final response = await _repository.iniciarMigracionTelefono(
        request: MigrarTelefonoIniciarRequestModel(
          codSocio: cleanCod,
          ci: cleanCi,
          pinActual: cleanPin,
          nuevoTelefono: cleanPhone,
          canal: canalNormalizado,
        ),
      );

      _startTimer(duration: 90);

      state = state.copyWith(
        isLoading: false,
        currentStep: 2,
        sessionId: response.sessionId,
        debugCodigoOtp: response.debugCodigoOtp,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al iniciar la migración. Verifique sus datos.',
      );
      return false;
    }
  }

  Future<bool> reenviarOtp() async {
    if (state.codSocio.isEmpty || state.nuevoTelefono.isEmpty) {
      state = state.copyWith(errorMessage: 'Datos de migración incompletos.');
      return false;
    }
    return iniciarMigracion(
      codSocio: state.codSocio,
      ci: state.ci,
      pinActual: state.pinActual,
      nuevoTelefono: state.nuevoTelefono,
      canal: state.canal,
    );
  }

  Future<bool> confirmarOtp(String codigoOtp) async {
    final cleanOtp = codigoOtp.trim();
    if (cleanOtp.length != 6) {
      state = state.copyWith(
        errorMessage: 'Ingrese el código OTP completo de 6 dígitos.',
      );
      return false;
    }
    final currentSession = state.sessionId;
    if (currentSession == null || currentSession.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Sesión de migración expirada. Inicie nuevamente.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _repository.confirmarMigracionTelefono(
        request: MigrarTelefonoConfirmarRequestModel(
          sessionId: currentSession,
          codigoOtp: cleanOtp,
        ),
      );

      // Guardar tokens y sesión autenticada en el AuthProvider global
      await _ref.read(authProvider.notifier).setAuthenticatedSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            codSocio: response.codSocio.isNotEmpty ? response.codSocio : state.codSocio,
            suministros: response.suministros,
          );

      state = state.copyWith(
        isLoading: false,
        migracionExitosa: true,
        successMessage: response.mensaje,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al confirmar la migración de teléfono.',
      );
      return false;
    }
  }

  void volverAlPaso1() {
    _timer?.cancel();
    state = MigrarCelularState(
      currentStep: 1,
      codSocio: state.codSocio,
      ci: state.ci,
      nombreTitular: state.nombreTitular,
      pinActual: state.pinActual,
      nuevoTelefono: state.nuevoTelefono,
      canal: state.canal,
      sessionId: null,
      debugCodigoOtp: null,
    );
  }

  void reset() {
    _timer?.cancel();
    state = const MigrarCelularState();
  }
}

final migrarCelularProvider =
    StateNotifierProvider.autoDispose<MigrarCelularNotifier, MigrarCelularState>(
        (ref) {
  final repository = ref.watch(authRepositoryProvider);
  return MigrarCelularNotifier(repository, ref);
});
