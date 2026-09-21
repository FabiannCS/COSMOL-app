import 'package:intl/intl.dart';

/// Modelo que representa un registro mensual de factura y consumo de agua.
class ConsumoFacturaModel {
  final String codigo;
  final String nombre;
  final int mes;
  final int anio;
  final double monto;
  final String estado; // '1' = Pagado, '0' = Pendiente
  final double consumo; // en m³
  final String? fecha;

  const ConsumoFacturaModel({
    required this.codigo,
    required this.nombre,
    required this.mes,
    required this.anio,
    required this.monto,
    required this.estado,
    required this.consumo,
    this.fecha,
  });

  factory ConsumoFacturaModel.fromJson(Map<String, dynamic> json) {
    return ConsumoFacturaModel(
      codigo: (json['CODIGO'] ?? json['codigo'] ?? '').toString().trim(),
      nombre: (json['NOMBRE'] ?? json['nombre'] ?? '').toString().trim(),
      mes: _parseInt(json['MES'] ?? json['mes']),
      anio: _parseInt(json['ANIO'] ?? json['anio'], defaultValue: DateTime.now().year),
      monto: _parseDouble(json['MONTO'] ?? json['monto']),
      estado: (json['ESTADO'] ?? json['estado'] ?? '1').toString().trim(),
      consumo: _parseDouble(json['CONSUMO'] ?? json['consumo']),
      fecha: json['FECHA']?.toString() ?? json['fecha']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'CODIGO': codigo,
      'NOMBRE': nombre,
      'MES': mes.toString(),
      'ANIO': anio.toString(),
      'MONTO': monto.toStringAsFixed(2),
      'ESTADO': estado,
      'CONSUMO': consumo.toStringAsFixed(0),
      if (fecha != null) 'FECHA': fecha,
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

  /// Indica si la factura fue pagada
  bool get isPagado => estado == '1' || estado.toLowerCase() == 'pagado';

  /// Nombre abreviado del mes en español (Ene, Feb, Mar, etc.)
  String get mesNombreCorto {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    if (mes >= 1 && mes <= 12) {
      return meses[mes - 1];
    }
    return 'Mes $mes';
  }

  /// Nombre completo del mes (Enero, Febrero, etc.)
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

  /// Etiqueta combinada: "Oct 2026"
  String get mesAnioCorto => '$mesNombreCorto $anio';

  /// Etiqueta combinada completa: "Octubre 2026"
  String get mesAnioCompleto => '$mesNombreCompleto $anio';

  /// Monto formateado en moneda boliviana: "Bs 58.01"
  String get montoFormateado {
    final format = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);
    return format.format(monto);
  }

  /// Volumen formateado: "15 m³"
  String get consumoFormateado {
    if (consumo == consumo.roundToDouble()) {
      return '${consumo.toInt()} m³';
    }
    return '${consumo.toStringAsFixed(1)} m³';
  }

  /// Tarifa calculada por m³ (si consumo > 0)
  double get tarifaPorM3 => consumo > 0 ? (monto / consumo) : 0.0;
}

/// Respuesta de la API de historial de facturas
class ConsumoHistorialResponse {
  final String estado;
  final String mensaje;
  final List<ConsumoFacturaModel> datos;

  const ConsumoHistorialResponse({
    required this.estado,
    required this.mensaje,
    required this.datos,
  });

  factory ConsumoHistorialResponse.fromJson(Map<String, dynamic> json) {
    final rawDatos = json['datos'] as List<dynamic>? ?? [];
    return ConsumoHistorialResponse(
      estado: json['estado']?.toString() ?? 'exito',
      mensaje: json['mensaje']?.toString() ?? '',
      datos: rawDatos
          .whereType<Map<String, dynamic>>()
          .map((item) => ConsumoFacturaModel.fromJson(item))
          .toList(),
    );
  }
}
