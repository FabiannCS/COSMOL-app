import 'package:intl/intl.dart';

/// Datos catastrales y del titular del suministro en COSMOL.
class DetalleSuministroModel {
  final String codSocio;
  final String nombreTitular;
  final String ciNit;
  final String direccion;
  final String ubicacion;
  final String categoria;
  final String rolUsuario;

  const DetalleSuministroModel({
    required this.codSocio,
    required this.nombreTitular,
    required this.ciNit,
    required this.direccion,
    required this.ubicacion,
    required this.categoria,
    required this.rolUsuario,
  });

  factory DetalleSuministroModel.fromJson(Map<String, dynamic> json) {
    return DetalleSuministroModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      nombreTitular: json['nombre_titular']?.toString().trim() ?? '',
      ciNit: json['ci_nit']?.toString().trim() ?? '',
      direccion: json['direccion']?.toString().trim() ?? '',
      ubicacion: json['ubicacion']?.toString().trim() ?? '',
      categoria: json['categoria']?.toString().trim() ?? 'DOMESTICA',
      rolUsuario: json['rol_usuario']?.toString().trim() ?? 'TITULAR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      'nombre_titular': nombreTitular,
      'ci_nit': ciNit,
      'direccion': direccion,
      'ubicacion': ubicacion,
      'categoria': categoria,
      'rol_usuario': rolUsuario,
    };
  }
}

/// Factura mensual impaga emitida por el sistema comercial de COSMOL.
class FacturaPendienteModel {
  final String nroFacip;
  final String nroFactura;
  final String codAutorizacion;
  final String periodo;
  final String mesLectura;
  final int anio;
  final int mes;
  final double montoBs;
  final bool estaVencida;
  final int diasMora;

  const FacturaPendienteModel({
    required this.nroFacip,
    required this.nroFactura,
    required this.codAutorizacion,
    required this.periodo,
    required this.mesLectura,
    required this.anio,
    required this.mes,
    required this.montoBs,
    required this.estaVencida,
    required this.diasMora,
  });

  factory FacturaPendienteModel.fromJson(Map<String, dynamic> json) {
    return FacturaPendienteModel(
      nroFacip: json['nro_facip']?.toString() ?? '',
      nroFactura: json['nro_factura']?.toString() ?? '',
      codAutorizacion: json['cod_autorizacion']?.toString() ?? '',
      periodo: json['periodo']?.toString() ?? '',
      mesLectura: json['mes_lectura']?.toString().trim() ?? '',
      anio: (json['anio'] as num?)?.toInt() ?? DateTime.now().year,
      mes: (json['mes'] as num?)?.toInt() ?? 1,
      montoBs: (json['monto_bs'] as num?)?.toDouble() ?? 0.0,
      estaVencida: json['esta_vencida'] as bool? ?? false,
      diasMora: (json['dias_mora'] as num?)?.toInt() ?? 0,
    );
  }

  String get montoFormateado {
    final format = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs ', decimalDigits: 2);
    return format.format(montoBs);
  }
}

/// Resumen integral de deuda de un suministro específico.
class ResumenDeudaModel {
  final String codSocio;
  final DetalleSuministroModel? suministro;
  final String moneda;
  final double saldoPendienteBs;
  final int cantidadFacturasPendientes;
  final String? fechaProximoVencimiento;
  final bool estaVencido;
  final bool alertaCorte;
  final String? mensajeAlerta;
  final List<FacturaPendienteModel> facturasPendientes;
  final String origenDatos;

  const ResumenDeudaModel({
    required this.codSocio,
    this.suministro,
    this.moneda = 'Bs',
    required this.saldoPendienteBs,
    required this.cantidadFacturasPendientes,
    this.fechaProximoVencimiento,
    required this.estaVencido,
    required this.alertaCorte,
    this.mensajeAlerta,
    this.facturasPendientes = const [],
    this.origenDatos = 'SISTEMA_LEGADO',
  });

  factory ResumenDeudaModel.fromJson(Map<String, dynamic> json) {
    final rawFacturas = json['facturas_pendientes'] as List<dynamic>? ?? [];
    return ResumenDeudaModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      suministro: json['suministro'] != null
          ? DetalleSuministroModel.fromJson(json['suministro'] as Map<String, dynamic>)
          : null,
      moneda: json['moneda']?.toString() ?? 'Bs',
      saldoPendienteBs: (json['saldo_pendiente_bs'] as num?)?.toDouble() ?? 0.0,
      cantidadFacturasPendientes:
          (json['cantidad_facturas_pendientes'] as num?)?.toInt() ?? 0,
      fechaProximoVencimiento: json['fecha_proximo_vencimiento']?.toString(),
      estaVencido: json['esta_vencido'] as bool? ?? false,
      alertaCorte: json['alerta_corte'] as bool? ?? false,
      mensajeAlerta: json['mensaje_alerta']?.toString(),
      facturasPendientes: rawFacturas
          .whereType<Map<String, dynamic>>()
          .map((item) => FacturaPendienteModel.fromJson(item))
          .toList(),
      origenDatos: json['origen_datos']?.toString() ?? 'SISTEMA_LEGADO',
    );
  }

  bool get hasDebt => saldoPendienteBs > 0 || cantidadFacturasPendientes > 0;

  String get saldoFormateado {
    final format = NumberFormat.currency(locale: 'es_BO', symbol: '', decimalDigits: 2);
    return format.format(saldoPendienteBs).trim();
  }
}
