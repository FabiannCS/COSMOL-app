import 'package:intl/intl.dart';

/// Representa el consumo y lecturas de medidor de un periodo mensual específico.
class ConsumoPeriodoModel {
  final String periodo;
  final int mes;
  final String mesNombre;
  final int anio;
  final double consumoM3;
  final double montoBs;
  final double lecturaAnterior;
  final double lecturaActual;
  final String? fechaLectura;
  final String estadoLectura;

  const ConsumoPeriodoModel({
    required this.periodo,
    required this.mes,
    required this.mesNombre,
    required this.anio,
    required this.consumoM3,
    required this.montoBs,
    required this.lecturaAnterior,
    required this.lecturaActual,
    this.fechaLectura,
    this.estadoLectura = 'NORMAL',
  });

  factory ConsumoPeriodoModel.fromJson(Map<String, dynamic> json) {
    final rawMes = _parseInt(json['mes'] ?? json['MES'] ?? json['nmes']);
    final rawAnio = _parseInt(json['anio'] ?? json['ANIO'] ?? json['gestion'], defaultValue: DateTime.now().year);
    final rawPeriodo = (json['periodo'] ?? '${rawMes.toString().padLeft(2, '0')}/$rawAnio').toString().trim();
    final rawMesNombre = json['mes_nombre']?.toString() ?? _obtenerMesNombre(rawMes, rawAnio);

    return ConsumoPeriodoModel(
      periodo: rawPeriodo,
      mes: rawMes,
      mesNombre: rawMesNombre,
      anio: rawAnio,
      consumoM3: _parseDouble(json['consumo_m3'] ?? json['consumo'] ?? json['CONSUMO'] ?? json['volumen']),
      montoBs: _parseDouble(json['monto_bs'] ?? json['monto'] ?? json['MONTO'] ?? json['montototal']),
      lecturaAnterior: _parseDouble(json['lectura_anterior'] ?? json['lect_ant'] ?? json['LECTURA_ANTERIOR']),
      lecturaActual: _parseDouble(json['lectura_actual'] ?? json['lect_act'] ?? json['LECTURA_ACTUAL']),
      fechaLectura: json['fecha_lectura']?.toString() ?? json['fecha']?.toString() ?? json['FECHA']?.toString(),
      estadoLectura: (json['estado_lectura'] ?? json['estado'] ?? json['ESTADO'] ?? 'NORMAL').toString().trim().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'periodo': periodo,
      'mes': mes,
      'mes_nombre': mesNombre,
      'anio': anio,
      'consumo_m3': consumoM3,
      'monto_bs': montoBs,
      'lectura_anterior': lecturaAnterior,
      'lectura_actual': lecturaActual,
      if (fechaLectura != null) 'fecha_lectura': fechaLectura,
      'estado_lectura': estadoLectura,
    };
  }

  static int _parseInt(dynamic value, {int defaultValue = 1}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final clean = value.replaceAll(',', '.').trim();
      return double.tryParse(clean) ?? defaultValue;
    }
    return defaultValue;
  }

  static String _obtenerMesNombre(int mes, int anio) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    if (mes >= 1 && mes <= 12) {
      return '${meses[mes - 1]} $anio';
    }
    return 'Mes $mes $anio';
  }

  // Getters auxiliares y de compatibilidad
  double get consumo => consumoM3;
  double get monto => montoBs;
  String get estado => estadoLectura;
  String? get fecha => fechaLectura;

  bool get isPagado =>
      estadoLectura == '1' ||
      estadoLectura == 'NORMAL' ||
      estadoLectura.toLowerCase() == 'pagado';

  String get mesNombreCorto {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    if (mes >= 1 && mes <= 12) {
      return meses[mes - 1];
    }
    return 'M$mes';
  }

  String get mesNombreCompleto {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    if (mes >= 1 && mes <= 12) {
      return meses[mes - 1];
    }
    return 'Mes $mes';
  }

  String get mesAnioCorto => '$mesNombreCorto $anio';
  String get mesAnioCompleto => '$mesNombreCompleto $anio';

  String get montoFormateado {
    final format = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);
    return format.format(montoBs);
  }

  String get consumoFormateado {
    if (consumoM3 == consumoM3.roundToDouble()) {
      return '${consumoM3.toInt()} m³';
    }
    return '${consumoM3.toStringAsFixed(1)} m³';
  }

  int get litrosMedidos => (consumoM3 * 1000).toInt();

  double get tarifaPorM3 => consumoM3 > 0 ? (montoBs / consumoM3) : 0.0;
}

// Alias de retrocompatibilidad
typedef ConsumoFacturaModel = ConsumoPeriodoModel;

/// Métricas analíticas calculadas sobre el historial de consumos del socio.
class EstadisticasConsumoModel {
  final double promedioM3;
  final double consumoMaximoM3;
  final String mesConsumoMaximo;
  final double consumoMinimoM3;
  final String mesConsumoMinimo;
  final double consumoUltimoMesM3;
  final bool consumoAtipico;
  final double? porcentajeVariacionUltimoMes;
  final String? mensajeAlerta;
  final String tendencia; // SUBIENDO, BAJANDO, ESTABLE

  const EstadisticasConsumoModel({
    required this.promedioM3,
    required this.consumoMaximoM3,
    required this.mesConsumoMaximo,
    required this.consumoMinimoM3,
    required this.mesConsumoMinimo,
    required this.consumoUltimoMesM3,
    this.consumoAtipico = false,
    this.porcentajeVariacionUltimoMes,
    this.mensajeAlerta,
    this.tendencia = 'ESTABLE',
  });

  factory EstadisticasConsumoModel.fromJson(Map<String, dynamic> json) {
    return EstadisticasConsumoModel(
      promedioM3: ConsumoPeriodoModel._parseDouble(json['promedio_m3']),
      consumoMaximoM3: ConsumoPeriodoModel._parseDouble(json['consumo_maximo_m3']),
      mesConsumoMaximo: (json['mes_consumo_maximo'] ?? 'N/A').toString(),
      consumoMinimoM3: ConsumoPeriodoModel._parseDouble(json['consumo_minimo_m3']),
      mesConsumoMinimo: (json['mes_consumo_minimo'] ?? 'N/A').toString(),
      consumoUltimoMesM3: ConsumoPeriodoModel._parseDouble(json['consumo_ultimo_mes_m3']),
      consumoAtipico: json['consumo_atipico'] == true,
      porcentajeVariacionUltimoMes: json['porcentaje_variacion_ultimo_mes'] != null
          ? ConsumoPeriodoModel._parseDouble(json['porcentaje_variacion_ultimo_mes'])
          : null,
      mensajeAlerta: json['mensaje_alerta']?.toString(),
      tendencia: (json['tendencia'] ?? 'ESTABLE').toString().toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'promedio_m3': promedioM3,
      'consumo_maximo_m3': consumoMaximoM3,
      'mes_consumo_maximo': mesConsumoMaximo,
      'consumo_minimo_m3': consumoMinimoM3,
      'mes_consumo_minimo': mesConsumoMinimo,
      'consumo_ultimo_mes_m3': consumoUltimoMesM3,
      'consumo_atipico': consumoAtipico,
      if (porcentajeVariacionUltimoMes != null)
        'porcentaje_variacion_ultimo_mes': porcentajeVariacionUltimoMes,
      if (mensajeAlerta != null) 'mensaje_alerta': mensajeAlerta,
      'tendencia': tendencia,
    };
  }
}

/// Respuesta integral con el historial mensual y métricas analíticas del suministro.
class HistorialConsumoModel {
  final String codSocio;
  final String alias;
  final String rolAcceso; // TITULAR, CONSULTA_PAGO
  final String? nroMedidor;
  final int totalPeriodos;
  final List<ConsumoPeriodoModel> periodos;
  final EstadisticasConsumoModel estadisticas;

  const HistorialConsumoModel({
    required this.codSocio,
    required this.alias,
    required this.rolAcceso,
    this.nroMedidor,
    required this.totalPeriodos,
    required this.periodos,
    required this.estadisticas,
  });

  factory HistorialConsumoModel.fromJson(Map<String, dynamic> json) {
    final rawPeriodos = json['periodos'] ?? json['datos'] as List<dynamic>? ?? [];
    final parsedPeriodos = (rawPeriodos as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((item) => ConsumoPeriodoModel.fromJson(item))
        .toList();

    EstadisticasConsumoModel parsedStats;
    if (json['estadisticas'] is Map<String, dynamic>) {
      parsedStats = EstadisticasConsumoModel.fromJson(json['estadisticas'] as Map<String, dynamic>);
    } else {
      // Cálculo de contingencia si el backend no entregó el nodo estadístico
      final totalM3 = parsedPeriodos.fold<double>(0.0, (sum, p) => sum + p.consumoM3);
      final avg = parsedPeriodos.isNotEmpty ? (totalM3 / parsedPeriodos.length) : 0.0;
      final ult = parsedPeriodos.isNotEmpty ? parsedPeriodos.last.consumoM3 : 0.0;
      parsedStats = EstadisticasConsumoModel(
        promedioM3: double.parse(avg.toStringAsFixed(2)),
        consumoMaximoM3: parsedPeriodos.isNotEmpty
            ? parsedPeriodos.map((p) => p.consumoM3).reduce((a, b) => a > b ? a : b)
            : 0.0,
        mesConsumoMaximo: parsedPeriodos.isNotEmpty ? parsedPeriodos.last.periodo : 'N/A',
        consumoMinimoM3: parsedPeriodos.isNotEmpty
            ? parsedPeriodos.map((p) => p.consumoM3).reduce((a, b) => a < b ? a : b)
            : 0.0,
        mesConsumoMinimo: parsedPeriodos.isNotEmpty ? parsedPeriodos.first.periodo : 'N/A',
        consumoUltimoMesM3: ult,
        consumoAtipico: avg > 0 && ult >= (avg * 1.30),
        tendencia: 'ESTABLE',
      );
    }

    return HistorialConsumoModel(
      codSocio: (json['cod_socio'] ?? json['codigo'] ?? '').toString().trim(),
      alias: (json['alias'] ?? json['nombre'] ?? 'Mi Suministro').toString().trim(),
      rolAcceso: (json['rol_acceso'] ?? json['rol'] ?? 'TITULAR').toString().trim().toUpperCase(),
      nroMedidor: json['nro_medidor']?.toString(),
      totalPeriodos: parsedPeriodos.length,
      periodos: parsedPeriodos,
      estadisticas: parsedStats,
    );
  }

  bool get isTitular => rolAcceso == 'TITULAR';
}

// Alias de retrocompatibilidad
typedef ConsumoHistorialResponse = HistorialConsumoModel;
