import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/pago_model.dart';
import '../../data/repositories/pagos_repository_impl.dart';
import '../../domain/repositories/pagos_repository.dart';

class PagosState {
  final bool isLoading;
  final bool isRegistering;
  final CanalesPagoResponseModel? canalesResponse;
  final String? errorMessage;

  const PagosState({
    this.isLoading = false,
    this.isRegistering = false,
    this.canalesResponse,
    this.errorMessage,
  });

  PagosState copyWith({
    bool? isLoading,
    bool? isRegistering,
    CanalesPagoResponseModel? canalesResponse,
    String? errorMessage,
  }) {
    return PagosState(
      isLoading: isLoading ?? this.isLoading,
      isRegistering: isRegistering ?? this.isRegistering,
      canalesResponse: canalesResponse ?? this.canalesResponse,
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
}
