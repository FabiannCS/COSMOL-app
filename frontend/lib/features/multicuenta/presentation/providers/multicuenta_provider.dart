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

  List<SuministroModel> _ordenarPorJerarquia(List<SuministroModel> lista) {
    final copy = List<SuministroModel>.from(lista);
    copy.sort((a, b) {
      if (a.esSuministroPrincipal && !b.esSuministroPrincipal) return -1;
      if (!a.esSuministroPrincipal && b.esSuministroPrincipal) return 1;
      if (a.esTitular && !b.esTitular) return -1;
      if (!a.esTitular && b.esTitular) return 1;
      return a.codSocio.compareTo(b.codSocio);
    });
    return copy;
  }

  void _init(List<SuministroModel> initialSuministros, String? initialCodSocio) {
    if (initialSuministros.isNotEmpty) {
      final ordenados = _ordenarPorJerarquia(initialSuministros);
      SuministroModel? active;
      if (initialCodSocio != null && initialCodSocio.isNotEmpty) {
        active = ordenados.firstWhere(
          (s) => s.codSocio == initialCodSocio,
          orElse: () => ordenados.first,
        );
      } else {
        active = ordenados.first;
      }
      state = state.copyWith(
        suministros: ordenados,
        activeSuministro: active,
      );
    } else {
      cargarSuministros();
    }
  }

  Future<void> cargarSuministros() async {
    if (!mounted) return;

    // GUARDA ANTI-401: No disparar petición si el usuario aún no tiene sesión activa
    final token = await storageService.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rawLista = await repository.listarSuministros();
      final lista = _ordenarPorJerarquia(rawLista);
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

      if (!mounted) return;
      state = state.copyWith(
        suministros: lista,
        activeSuministro: active,
        isLoading: false,
      );

      // Persistir suministros para disponibilidad offline
      await storageService.saveCachedSuministros(
        lista.map((s) => s.toJson()).toList(),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      _aplicarFallbackOfflineSuministros(e.message);
    } catch (e) {
      if (!mounted) return;
      _aplicarFallbackOfflineSuministros('Error al cargar suministros.');
    }
  }

  Future<void> _aplicarFallbackOfflineSuministros(String defaultError) async {
    final cached = storageService.getCachedSuministros();
    if (cached != null && cached.isNotEmpty) {
      final listaCached = _ordenarPorJerarquia(
        cached.map((item) => SuministroModel.fromJson(item)).toList(),
      );
      final activeCod = await storageService.getActiveCodSocio();

      final active = (activeCod != null && activeCod.isNotEmpty)
          ? listaCached.firstWhere(
              (s) => s.codSocio == activeCod,
              orElse: () => listaCached.first,
            )
          : listaCached.first;

      state = state.copyWith(
        suministros: listaCached,
        activeSuministro: active,
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: defaultError,
    );
  }

  Future<void> seleccionarSuministro(SuministroModel suministro) async {
    await storageService.saveActiveCodSocio(suministro.codSocio);
    if (!mounted) return;
    state = state.copyWith(activeSuministro: suministro);
  }

  Future<bool> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final nuevoSuministro = await repository.vincularSuministro(
        codSocio: codSocio,
        ciOMedidor: ciOMedidor,
        alias: alias,
      );

      final nuevaLista = _ordenarPorJerarquia([...state.suministros, nuevoSuministro]);
      await storageService.saveActiveCodSocio(nuevoSuministro.codSocio);

      if (!mounted) return true;
      state = state.copyWith(
        suministros: nuevaLista,
        activeSuministro: nuevoSuministro,
        isLoading: false,
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
        errorMessage: 'Error al vincular el Socio.',
      );
      return false;
    }
  }

  Future<bool> desvincularSuministro(String codSocio) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await repository.desvincularSuministro(codSocio);

      final nuevaLista = _ordenarPorJerarquia(
          state.suministros.where((s) => s.codSocio != codSocio).toList());

      SuministroModel? nuevoActivo = state.activeSuministro;
      if (state.activeSuministro?.codSocio == codSocio) {
        nuevoActivo = nuevaLista.isNotEmpty
            ? nuevaLista.firstWhere((s) => s.esSuministroPrincipal,
                orElse: () => nuevaLista.first)
            : null;
        if (nuevoActivo != null) {
          await storageService.saveActiveCodSocio(nuevoActivo.codSocio);
        }
      }

      if (!mounted) return true;
      state = state.copyWith(
        suministros: nuevaLista,
        activeSuministro: nuevoActivo,
        isLoading: false,
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
        errorMessage: 'Error al desvincular el suministro.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
