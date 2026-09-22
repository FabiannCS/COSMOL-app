import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/consumo_factura_model.dart';
import '../../data/repositories/consumo_repository_impl.dart';
import '../../domain/repositories/consumo_repository.dart';

enum PeriodoConsumo {
  seisMeses,
  doceMeses,
}

class ConsumoState {
  final bool isLoading;
  final List<ConsumoFacturaModel> facturas;
  final PeriodoConsumo periodo;
  final int? selectedIndex;
  final String? errorMessage;
  final String? currentCodSocio;

  const ConsumoState({
    this.isLoading = false,
    this.facturas = const [],
    this.periodo = PeriodoConsumo.seisMeses,
    this.selectedIndex,
    this.errorMessage,
    this.currentCodSocio,
  });

  ConsumoState copyWith({
    bool? isLoading,
    List<ConsumoFacturaModel>? facturas,
    PeriodoConsumo? periodo,
    int? selectedIndex,
    String? errorMessage,
    String? currentCodSocio,
  }) {
    return ConsumoState(
      isLoading: isLoading ?? this.isLoading,
      facturas: facturas ?? this.facturas,
      periodo: periodo ?? this.periodo,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      errorMessage: errorMessage,
      currentCodSocio: currentCodSocio ?? this.currentCodSocio,
    );
  }

  /// Facturas filtradas por el período activo (6 o 12 meses)
  List<ConsumoFacturaModel> get filteredFacturas {
    final limit = periodo == PeriodoConsumo.seisMeses ? 6 : 12;
    if (facturas.length <= limit) return facturas;
    return facturas.take(limit).toList();
  }

  /// Factura del mes más reciente
  ConsumoFacturaModel? get mesActual =>
      facturas.isNotEmpty ? facturas.first : null;

  /// Consumo del mes más reciente en m³
  double get consumoActual => mesActual?.consumo ?? 0.0;

  /// Promedio de consumo del período activo
  double get promedioConsumo {
    final list = filteredFacturas;
    if (list.isEmpty) return 0.0;
    final total = list.fold<double>(0.0, (sum, item) => sum + item.consumo);
    return total / list.length;
  }

  /// Indica si el consumo del mes actual está por debajo del promedio del período
  bool get isBajoPromedio => consumoActual <= promedioConsumo;

  /// Factura actualmente seleccionada en la gráfica interactiva (por defecto la más reciente)
  ConsumoFacturaModel? get selectedFactura {
    final list = filteredFacturas;
    if (list.isEmpty) return null;
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < list.length) {
      return list[selectedIndex!];
    }
    return list.first;
  }

  /// Registro con menor consumo dentro del período (mayor ahorro)
  ConsumoFacturaModel? get mayorAhorroFactura {
    final list = filteredFacturas;
    if (list.isEmpty) return null;
    return list.reduce((curr, next) =>
        (curr.consumo > 0 && curr.consumo < next.consumo) ? curr : next);
  }

  /// Tarifa promedio o de referencia por m³
  double get tarifaReferencial {
    final list = filteredFacturas.where((f) => f.consumo > 0).toList();
    if (list.isEmpty) return 6.60;
    final totalTarifa =
        list.fold<double>(0.0, (sum, item) => sum + item.tarifaPorM3);
    return totalTarifa / list.length;
  }
}

final consumoProvider =
    StateNotifierProvider<ConsumoNotifier, ConsumoState>((ref) {
  final repository = ref.watch(consumoRepositoryProvider);
  final multicuentaState = ref.watch(multicuentaProvider);
  final activeCodSocio =
      multicuentaState.activeSuministro?.codSocio.trim();

  return ConsumoNotifier(
    repository: repository,
    initialCodSocio: activeCodSocio,
  );
});

class ConsumoNotifier extends StateNotifier<ConsumoState> {
  final ConsumoRepository repository;

  ConsumoNotifier({
    required this.repository,
    String? initialCodSocio,
  }) : super(ConsumoState(currentCodSocio: initialCodSocio)) {
    if (initialCodSocio != null && initialCodSocio.isNotEmpty) {
      cargarHistorial(codSocio: initialCodSocio);
    }
  }

  Future<void> cargarHistorial({String? codSocio, String? ci}) async {
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
      final facturas = await repository.obtenerHistorialConsumo(
        codSocio: targetCodSocio,
        ci: ci,
      );

      // Ordenar por año y mes descendente (el más reciente primero)
      facturas.sort((a, b) {
        final cmpAnio = b.anio.compareTo(a.anio);
        if (cmpAnio != 0) return cmpAnio;
        return b.mes.compareTo(a.mes);
      });

      state = state.copyWith(
        isLoading: false,
        facturas: facturas,
        selectedIndex: 0,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo cargar el historial de consumo.',
      );
    }
  }

  void cambiarPeriodo(PeriodoConsumo nuevoPeriodo) {
    if (state.periodo == nuevoPeriodo) return;
    state = state.copyWith(
      periodo: nuevoPeriodo,
      selectedIndex: 0,
    );
  }

  void seleccionarMes(int index) {
    if (index >= 0 && index < state.filteredFacturas.length) {
      state = state.copyWith(selectedIndex: index);
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
