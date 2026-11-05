import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/pago_model.dart';
import '../../data/repositories/pagos_repository_impl.dart';
import '../../domain/repositories/pagos_repository.dart';

class PagosState {
  final bool isLoading;
  final bool isRegistering;
  final bool isSimulating;
  final CanalesPagoResponseModel? canalesResponse;
  final SimularPagoResponseModel? ultimoPagoSimulado;
  final String? errorMessage;

  const PagosState({
    this.isLoading = false,
    this.isRegistering = false,
    this.isSimulating = false,
    this.canalesResponse,
    this.ultimoPagoSimulado,
    this.errorMessage,
  });

  PagosState copyWith({
    bool? isLoading,
    bool? isRegistering,
    bool? isSimulating,
    CanalesPagoResponseModel? canalesResponse,
    SimularPagoResponseModel? ultimoPagoSimulado,
    String? errorMessage,
  }) {
    return PagosState(
      isLoading: isLoading ?? this.isLoading,
      isRegistering: isRegistering ?? this.isRegistering,
      isSimulating: isSimulating ?? this.isSimulating,
      canalesResponse: canalesResponse ?? this.canalesResponse,
      ultimoPagoSimulado: ultimoPagoSimulado ?? this.ultimoPagoSimulado,
      errorMessage: errorMessage,
    );
  }

  List<CanalPagoModel> get canales => canalesResponse?.canales ?? const [];
}

final pagosProvider = StateNotifierProvider<PagosNotifier, PagosState>((ref) {
  final repository = ref.watch(pagosRepositoryProvider);
  return PagosNotifier(repository);
});

class PagosNotifier extends StateNotifier<PagosState> {
  final PagosRepository _repository;

  PagosNotifier(this._repository) : super(const PagosState());

  /// Consulta el catálogo oficial de canales de pago desde el backend.
  Future<void> cargarCanales(String codSocio) async {
    final cleanCod = codSocio.trim();
    if (cleanCod.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _repository.obtenerCanalesPago(codSocio: cleanCod);
      state = state.copyWith(
        isLoading: false,
        canalesResponse: response,
        errorMessage: null,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudieron consultar los canales de pago.',
      );
    }
  }

  /// Registra el clic en el canal seleccionado, activa la ventana de verificación en Redis y retorna la URL.
  Future<String?> registrarIntentoYObtenerUrl({
    required String codSocio,
    required String canalId,
  }) async {
    state = state.copyWith(isRegistering: true, errorMessage: null);

    try {
      final response = await _repository.registrarIntentoPago(
        codSocio: codSocio.trim(),
        canalId: canalId.trim(),
      );
      state = state.copyWith(isRegistering: false);
      return response.urlRedireccion;
    } on AppException catch (e) {
      state = state.copyWith(isRegistering: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isRegistering: false,
        errorMessage: 'Error al registrar el intento de pago.',
      );
      return null;
    }
  }

  /// Simula el pago mock (solo vista) y despacha telemetría a COSMOL-Reportes.
  Future<SimularPagoResponseModel?> simularPago({
    required String codSocio,
    required String canalId,
    required double montoBs,
    String? periodos,
  }) async {
    state = state.copyWith(isSimulating: true, errorMessage: null);

    try {
      final response = await _repository.simularPago(
        codSocio: codSocio.trim(),
        canalId: canalId.trim(),
        montoBs: montoBs,
        periodos: periodos,
      );
      state = state.copyWith(
        isSimulating: false,
        ultimoPagoSimulado: response,
        errorMessage: null,
      );
      return response;
    } on AppException catch (e) {
      state = state.copyWith(isSimulating: false, errorMessage: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isSimulating: false,
        errorMessage: 'Error al procesar la simulación de pago.',
      );
      return null;
    }
  }
}
