import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/data/models/login_response_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/multicuenta_repository_impl.dart';
import '../../domain/repositories/multicuenta_repository.dart';

class MulticuentaState {
  final List<SuministroModel> suministros;
  final SuministroModel? activeSuministro;
  final bool isLoading;
  final String? errorMessage;

  const MulticuentaState({
    this.suministros = const [],
    this.activeSuministro,
    this.isLoading = false,
    this.errorMessage,
  });

  MulticuentaState copyWith({
    List<SuministroModel>? suministros,
    SuministroModel? activeSuministro,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MulticuentaState(
      suministros: suministros ?? this.suministros,
      activeSuministro: activeSuministro ?? this.activeSuministro,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final multicuentaProvider =
    StateNotifierProvider<MulticuentaNotifier, MulticuentaState>((ref) {
  final repository = ref.watch(multicuentaRepositoryProvider);
  final storageService = ref.watch(storageServiceProvider);
  final authState = ref.watch(authProvider);

  return MulticuentaNotifier(
    repository: repository,
    storageService: storageService,
    initialSuministros: authState.suministros,
    initialCodSocio: authState.activeCodSocio,
  );
});

class MulticuentaNotifier extends StateNotifier<MulticuentaState> {
  final MulticuentaRepository repository;
  final StorageService storageService;

  MulticuentaNotifier({
    required this.repository,
    required this.storageService,
    List<SuministroModel> initialSuministros = const [],
    String? initialCodSocio,
  }) : super(const MulticuentaState()) {
    _init(initialSuministros, initialCodSocio);
  }

  void _init(List<SuministroModel> initialSuministros, String? initialCodSocio) {
    if (initialSuministros.isNotEmpty) {
      SuministroModel? active;
      if (initialCodSocio != null && initialCodSocio.isNotEmpty) {
        active = initialSuministros.firstWhere(
          (s) => s.codSocio == initialCodSocio,
          orElse: () => initialSuministros.first,
        );
      } else {
        active = initialSuministros.first;
      }
      state = state.copyWith(
        suministros: initialSuministros,
        activeSuministro: active,
      );
    } else {
      cargarSuministros();
    }
  }

  Future<void> cargarSuministros() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final lista = await repository.listarSuministros();
      final activeCodSocio = await storageService.getActiveCodSocio();

      SuministroModel? active;
      if (lista.isNotEmpty) {
        if (activeCodSocio != null && activeCodSocio.isNotEmpty) {
          active = lista.firstWhere(
            (s) => s.codSocio == activeCodSocio,
            orElse: () => lista.first,
          );
        } else {
          active = lista.first;
        }
        await storageService.saveActiveCodSocio(active.codSocio);
      }

      state = state.copyWith(
        suministros: lista,
        activeSuministro: active,
        isLoading: false,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cargar suministros.',
      );
    }
  }

  Future<void> seleccionarSuministro(SuministroModel suministro) async {
    await storageService.saveActiveCodSocio(suministro.codSocio);
    state = state.copyWith(activeSuministro: suministro);
  }

  Future<bool> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final nuevoSuministro = await repository.vincularSuministro(
        codSocio: codSocio,
        ciOMedidor: ciOMedidor,
        alias: alias,
      );

      final nuevaLista = [...state.suministros, nuevoSuministro];
      await storageService.saveActiveCodSocio(nuevoSuministro.codSocio);

      state = state.copyWith(
        suministros: nuevaLista,
        activeSuministro: nuevoSuministro,
        isLoading: false,
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
        errorMessage: 'Error al vincular el suministro.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
