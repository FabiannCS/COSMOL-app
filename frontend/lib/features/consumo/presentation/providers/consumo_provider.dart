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

  /// Mes inmediatamente anterior al mes más reciente (cronológicamente el previo)
  ConsumoPeriodoModel? get mesAnteriorAlActual {
    final list = allFacturasDescendente;
    return list.length > 1 ? list[1] : null;
  }

  /// Variación porcentual del mes actual respecto al mes anterior
  double? get variacionVsMesAnterior {
    final mesAnt = mesAnteriorAlActual;
    if (mesActual == null || mesAnt == null || mesAnt.consumoM3 <= 0) return null;
    final varPct = ((consumoActual - mesAnt.consumoM3) / mesAnt.consumoM3) * 100.0;
    return double.parse(varPct.toStringAsFixed(1));
  }

  /// Promedio de consumo calculado sobre el período activo seleccionado (6 o 12 meses)
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

  /// Obtiene el mes anterior cronológico a una factura específica en el historial completo
  ConsumoPeriodoModel? getMesAnterior(ConsumoPeriodoModel factura) {
    final list = allFacturasDescendente;
    final index = list.indexWhere((f) => f.mes == factura.mes && f.anio == factura.anio);
    if (index != -1 && index + 1 < list.length) {
      return list[index + 1];
    }
    return null;
  }

  /// Variación porcentual de una factura específica respecto a su mes anterior
  double? getVariacionVsMesAnterior(ConsumoPeriodoModel factura) {
    final mesAnt = getMesAnterior(factura);
    if (mesAnt == null || mesAnt.consumoM3 <= 0) return null;
    final varPct = ((factura.consumoM3 - mesAnt.consumoM3) / mesAnt.consumoM3) * 100.0;
    return double.parse(varPct.toStringAsFixed(1));
  }

  /// Determina si una factura específica tiene un incremento mayor al 40% respecto a su mes anterior
  bool tieneAlertaFuga(ConsumoPeriodoModel factura) {
    final mesAnt = getMesAnterior(factura);
    if (mesAnt == null || mesAnt.consumoM3 <= 0) return false;
    return ((factura.consumoM3 - mesAnt.consumoM3) / mesAnt.consumoM3) > 0.40;
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

  /// Indica si el mes actual tiene alerta de consumo elevado y posible fuga.
  /// REGLA ESTRICTA: Se activa ÚNICAMENTE cuando el consumo del mes es mayor al 40% en comparación al mes anterior.
  bool get consumoAtipico {
    final mesAnt = mesAnteriorAlActual;
    if (mesActual == null || mesAnt == null || mesAnt.consumoM3 <= 0) return false;
    return ((consumoActual - mesAnt.consumoM3) / mesAnt.consumoM3) > 0.40;
  }

  /// Mensaje preventivo oficial cuando se detecta consumo elevado mayor al 40% vs mes anterior
  String? get mensajeAlerta {
    if (!consumoAtipico) return null;
    final mesAnt = mesAnteriorAlActual;
    final varPct = variacionVsMesAnterior ?? 0.0;
    final actualStr = consumoActual == consumoActual.roundToDouble()
        ? '${consumoActual.toInt()}'
        : consumoActual.toStringAsFixed(1);
    final antStr = mesAnt != null
        ? (mesAnt.consumoM3 == mesAnt.consumoM3.roundToDouble()
            ? '${mesAnt.consumoM3.toInt()}'
            : mesAnt.consumoM3.toStringAsFixed(1))
        : '';
    return 'Detectamos un consumo de $actualStr m³, un +${varPct.toStringAsFixed(1)}% superior al mes anterior ($antStr m³). Le sugerimos revisar sus instalaciones internas para descartar posibles fugas de agua.';
  }

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
  final activeCodSocio = ref.watch(
    multicuentaProvider.select((s) => s.activeSuministro?.codSocio.trim() ?? ''),
  );

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
    final targetCodSocio = codSocio ?? state.currentCodSocio ?? '';

    // Si ya tenemos datos y solo refrescamos, marcamos isRefreshing para no parpadear toda la pantalla
    final esPrimeraCarga = state.historial == null || targetCodSocio != state.currentCodSocio;

    if (!mounted) return;
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

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        historial: historial,
        selectedIndex: 0,
        errorMessage: null,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
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
