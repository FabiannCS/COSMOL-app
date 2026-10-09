import 'package:intl/intl.dart';

/// Representa una factura dentro del historial cronológico de 12 meses de COSMOL R.L.
/// Consumido desde GET /api-consultas/socios/{cod_socio}/historial-facturas
class HistorialFacturaItemModel {
  final String codigo;
  final String nombre;
  final int mes;
  final int anio;
  final double monto;
  final String estado; // "1" = Pagado, "0" = Pendiente
  final double consumoM3;
  final String? fechaPago; // Fecha de pago real, ej: "2026-09-05" o null
  final String? nroFactura; // Asociado cuando esté disponible

  const HistorialFacturaItemModel({
    required this.codigo,
    required this.nombre,
    required this.mes,
    required this.anio,
    required this.monto,
    required this.estado,
    required this.consumoM3,
    this.fechaPago,
    this.nroFactura,
  });

  factory HistorialFacturaItemModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().trim().replaceAll(',', '.')) ?? 0.0;
    }

    int parseInt(dynamic v, {int fallback = 1}) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim()) ?? fallback;
    }

    return HistorialFacturaItemModel(
      codigo: json['CODIGO']?.toString().trim() ?? json['codigo']?.toString().trim() ?? '',
      nombre: json['NOMBRE']?.toString().trim() ?? json['nombre']?.toString().trim() ?? '',
      mes: parseInt(json['MES'] ?? json['mes']),
      anio: parseInt(json['ANIO'] ?? json['anio'], fallback: DateTime.now().year),
      monto: parseDouble(json['MONTO'] ?? json['monto']),
      estado: json['ESTADO']?.toString().trim() ?? json['estado']?.toString().trim() ?? '0',
      consumoM3: parseDouble(json['CONSUMO'] ?? json['consumo']),
      fechaPago: json['FECHA']?.toString().trim() ?? json['fecha']?.toString().trim(),
      nroFactura: json['NROFACTURA']?.toString().trim() ?? json['nro_factura']?.toString().trim(),
    );
  }

  HistorialFacturaItemModel copyWith({
    String? nroFactura,
  }) {
    return HistorialFacturaItemModel(
      codigo: codigo,
      nombre: nombre,
      mes: mes,
      anio: anio,
      monto: monto,
      estado: estado,
      consumoM3: consumoM3,
      fechaPago: fechaPago,
      nroFactura: nroFactura ?? this.nroFactura,
    );
  }

  bool get isPagado => estado == '1' || (fechaPago != null && fechaPago!.isNotEmpty);

  String get periodo => '${mes.toString().padLeft(2, '0')}/$anio';

  String get periodoFormateado {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    if (mes >= 1 && mes <= 12) {
      return '${meses[mes - 1]} $anio';
    }
    return '$mes/$anio';
  }

  String get montoFormateado {
    final format = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs', decimalDigits: 2);
    return format.format(monto);
  }

  String get consumoFormateado {
    if (consumoM3 == consumoM3.roundToDouble()) {
      return '${consumoM3.toInt()} m³';
    }
    return '${consumoM3.toStringAsFixed(1)} m³';
  }

  String get fechaPagoFormateada {
    if (fechaPago == null || fechaPago!.isEmpty) return 'Pendiente';
    try {
      final parsed = DateTime.parse(fechaPago!);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return fechaPago!;
    }
  }
}
