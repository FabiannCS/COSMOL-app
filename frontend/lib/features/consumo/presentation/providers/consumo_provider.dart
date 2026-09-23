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
  final bool isRefreshing;
  final HistorialConsumoModel? historial;
  final PeriodoConsumo periodo;
  final int selectedIndex;
  final String? errorMessage;
  final String? currentCodSocio;

  const ConsumoState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.historial,
    this.periodo = PeriodoConsumo.seisMeses,
    this.selectedIndex = 0,
    this.errorMessage,
    this.currentCodSocio,
  });

  ConsumoState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    HistorialConsumoModel? historial,
    PeriodoConsumo? periodo,
    int? selectedIndex,
    String? errorMessage,
    String? currentCodSocio,
  }) {
    return ConsumoState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      historial: historial ?? this.historial,
      periodo: periodo ?? this.periodo,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      errorMessage: errorMessage,
      currentCodSocio: currentCodSocio ?? this.currentCodSocio,
    );
  }

  /// Todos los periodos ordenados de forma descendente (el más reciente primero)
  List<ConsumoPeriodoModel> get allFacturasDescendente {
    if (historial == null || historial!.periodos.isEmpty) return const [];
    final list = List<ConsumoPeriodoModel>.from(historial!.periodos);
    list.sort((a, b) {
      final cmpAnio = b.anio.compareTo(a.anio);
      if (cmpAnio != 0) return cmpAnio;
      return b.mes.compareTo(a.mes);
    });
    return list;
  }

  /// Periodos filtrados según la ventana temporal activa (6 o 12 meses)
  List<ConsumoPeriodoModel> get filteredFacturas {
    final list = allFacturasDescendente;
    final limit = periodo == PeriodoConsumo.seisMeses ? 6 : 12;
    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  /// Facturas en orden cronológico (el más antiguo a la izquierda) para renderizado de gráficas
  List<ConsumoPeriodoModel> get chronologicFacturas {
    final list = List<ConsumoPeriodoModel>.from(filteredFacturas);
    list.sort((a, b) {
      final cmpAnio = a.anio.compareTo(b.anio);
      if (cmpAnio != 0) return cmpAnio;
      return a.mes.compareTo(b.mes);
    });
    return list;
  }

  /// Periodo del mes más reciente
  ConsumoPeriodoModel? get mesActual =>
      filteredFacturas.isNotEmpty ? filteredFacturas.first : null;

  /// Consumo del mes más reciente en m³
  double get consumoActual => mesActual?.consumoM3 ?? 0.0;

  /// Promedio de consumo calculado sobre el período activo (6 o 12 meses)
  double get promedioConsumo {
    final list = filteredFacturas;
    if (list.isEmpty) return historial?.estadisticas.promedioM3 ?? 0.0;
    final total = list.fold<double>(0.0, (sum, item) => sum + item.consumoM3);
    return double.parse((total / list.length).toStringAsFixed(2));
  }

  /// Indica si el consumo del mes actual está por debajo o igual al promedio del período
  bool get isBajoPromedio => consumoActual <= promedioConsumo;

  /// Factura actualmente seleccionada en la gráfica interactiva (por defecto la más reciente)
  ConsumoPeriodoModel? get selectedFactura {
    final list = filteredFacturas;
    if (list.isEmpty) return null;
    final index = selectedIndex.clamp(0, list.length - 1);
    return list[index];
  }

  /// Registro con menor consumo dentro del período (mayor ahorro)
  ConsumoPeriodoModel? get mayorAhorroFactura {
    final list = filteredFacturas;
    if (list.isEmpty) return null;
    return list.reduce((curr, next) =>
        (curr.consumoM3 > 0 && curr.consumoM3 < next.consumoM3) ? curr : next);
  }

  /// Tarifa promedio o de referencia por m³ en el período
  double get tarifaReferencial {
    final list = filteredFacturas.where((f) => f.consumoM3 > 0).toList();
    if (list.isEmpty) return 6.60;
    final totalTarifa =
        list.fold<double>(0.0, (sum, item) => sum + item.tarifaPorM3);
    return double.parse((totalTarifa / list.length).toStringAsFixed(2));
  }

  /// Indica si el backend detectó consumo atípico o fuga preventiva
  bool get consumoAtipico =>
      historial?.estadisticas.consumoAtipico ??
      (promedioConsumo > 0 && consumoActual >= (promedioConsumo * 1.30));

  /// Mensaje oficial preventivo de fuga
  String? get mensajeAlerta =>
      historial?.estadisticas.mensajeAlerta ??
      (consumoAtipico
          ? 'Detectamos un consumo anormalmente alto en el último periodo. Le sugerimos revisar sus instalaciones internas para descartar posibles fugas de agua.'
          : null);

  /// Tendencia de consumo (SUBIENDO, BAJANDO, ESTABLE)
  String get tendencia => historial?.estadisticas.tendencia ?? 'ESTABLE';

  /// Número de medidor instalado
  String? get nroMedidor => historial?.nroMedidor;

  /// Rol del usuario sobre este suministro (TITULAR vs CONSULTA_PAGO)
  String get rolAcceso => historial?.rolAcceso ?? 'TITULAR';
  bool get isTitular => rolAcceso == 'TITULAR';
}

final consumoProvider =
    StateNotifierProvider<ConsumoNotifier, ConsumoState>((ref) {
  final repository = ref.watch(consumoRepositoryProvider);
  final multicuentaState = ref.watch(multicuentaProvider);
  final activeCodSocio =
      multicuentaState.activeSuministro?.codSocio.trim() ?? '23807';

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

  Future<void> cargarHistorial({
    String? codSocio,
    bool forzarRefresco = false,
  }) async {
    final targetCodSocio = codSocio ?? state.currentCodSocio ?? '23807';

    // Si ya tenemos datos y solo refrescamos, marcamos isRefreshing para no parpadear toda la pantalla
    final esPrimeraCarga = state.historial == null || targetCodSocio != state.currentCodSocio;

    state = state.copyWith(
      isLoading: esPrimeraCarga,
      isRefreshing: !esPrimeraCarga,
      errorMessage: null,
      currentCodSocio: targetCodSocio,
    );

    try {
      final historial = await repository.obtenerHistorialConsumo(
        codSocio: targetCodSocio,
        forzarRefresco: forzarRefresco,
        meses: 12,
      );

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        historial: historial,
        selectedIndex: 0,
        errorMessage: null,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'No se pudo cargar el historial de consumo desde COSMOL.',
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
