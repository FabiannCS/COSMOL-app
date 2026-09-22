import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/deuda_response_model.dart';
import '../../data/repositories/deuda_repository_impl.dart';
import '../../domain/repositories/deuda_repository.dart';

class DeudaState {
  final bool isLoading;
  final ResumenDeudaModel? deuda;
  final String? errorMessage;
  final String? currentCodSocio;

  const DeudaState({
    this.isLoading = false,
    this.deuda,
    this.errorMessage,
    this.currentCodSocio,
  });

  DeudaState copyWith({
    bool? isLoading,
    ResumenDeudaModel? deuda,
    String? errorMessage,
    String? currentCodSocio,
  }) {
    return DeudaState(
      isLoading: isLoading ?? this.isLoading,
      deuda: deuda ?? this.deuda,
      errorMessage: errorMessage,
      currentCodSocio: currentCodSocio ?? this.currentCodSocio,
    );
  }
}

final deudaProvider = StateNotifierProvider<DeudaNotifier, DeudaState>((ref) {
  final repository = ref.watch(deudaRepositoryProvider);
  final multicuentaState = ref.watch(multicuentaProvider);
  final activeCodSocio = multicuentaState.activeSuministro?.codSocio.trim();

  return DeudaNotifier(
    repository: repository,
    initialCodSocio: activeCodSocio,
  );
});

class DeudaNotifier extends StateNotifier<DeudaState> {
  final DeudaRepository repository;

  DeudaNotifier({
    required this.repository,
    String? initialCodSocio,
  }) : super(DeudaState(currentCodSocio: initialCodSocio)) {
    if (initialCodSocio != null && initialCodSocio.isNotEmpty) {
      cargarDeuda(codSocio: initialCodSocio);
    }
  }

  Future<void> cargarDeuda({
    String? codSocio,
    bool forzarRefresco = false,
  }) async {
    final targetCodSocio = codSocio ?? state.currentCodSocio;
    if (targetCodSocio == null || targetCodSocio.isEmpty) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      currentCodSocio: targetCodSocio,
    );

    try {
      final deuda = await repository.obtenerDeudaSuministro(
        codSocio: targetCodSocio,
        forzarRefresco: forzarRefresco,
      );

      state = state.copyWith(
        isLoading: false,
        deuda: deuda,
        errorMessage: null,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo consultar el estado de deuda del suministro.',
      );
    }
  }
}
