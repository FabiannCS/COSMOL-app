/// Modelos DTO para la Consulta de Deuda y Resumen de Suministro
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
    this.diasMora = 0,
  });

  factory FacturaPendienteModel.fromJson(Map<String, dynamic> json) {
    return FacturaPendienteModel(
      nroFacip: json['nro_facip']?.toString() ?? '',
      nroFactura: json['nro_factura']?.toString() ?? '',
      codAutorizacion: json['cod_autorizacion']?.toString() ?? '',
      periodo: json['periodo']?.toString() ?? '',
      mesLectura: json['mes_lectura']?.toString() ?? '',
      anio: (json['anio'] as num?)?.toInt() ?? 2026,
      mes: (json['mes'] as num?)?.toInt() ?? 1,
      montoBs: (json['monto_bs'] as num?)?.toDouble() ?? 0.0,
      estaVencida: json['esta_vencida'] == true,
      diasMora: (json['dias_mora'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nro_facip': nroFacip,
      'nro_factura': nroFactura,
      'cod_autorizacion': codAutorizacion,
      'periodo': periodo,
      'mes_lectura': mesLectura,
      'anio': anio,
      'mes': mes,
      'monto_bs': montoBs,
      'esta_vencida': estaVencida,
      'dias_mora': diasMora,
    };
  }
}

class DetalleSuministroModel {
  final String codSocio;
  final String nombreTitular;
  final String ciNit;
  final String direccion;
  final String ubicacion;
  final String categoria;
  final String rolUsuario;
  final String telefonoCelular;

  const DetalleSuministroModel({
    required this.codSocio,
    required this.nombreTitular,
    required this.ciNit,
    required this.direccion,
    required this.ubicacion,
    this.categoria = 'DOMESTICA',
    this.rolUsuario = 'TITULAR',
    this.telefonoCelular = '',
  });

  factory DetalleSuministroModel.fromJson(Map<String, dynamic> json) {
    return DetalleSuministroModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      nombreTitular: json['nombre_titular']?.toString() ?? '',
      ciNit: json['ci_nit']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      ubicacion: json['ubicacion']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? 'DOMESTICA',
      rolUsuario: json['rol_usuario']?.toString() ?? 'TITULAR',
      telefonoCelular: json['telefono_celular']?.toString() ?? json['telefono']?.toString() ?? json['celular']?.toString() ?? '',
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
      'telefono_celular': telefonoCelular,
    };
  }
}

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
  final String? fechaConsulta;
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
    this.fechaConsulta,
    this.origenDatos = 'SISTEMA_LEGADO',
  });

  ResumenDeudaModel copyWith({
    String? codSocio,
    DetalleSuministroModel? suministro,
    String? moneda,
    double? saldoPendienteBs,
    int? cantidadFacturasPendientes,
    String? fechaProximoVencimiento,
    bool? estaVencido,
    bool? alertaCorte,
    String? mensajeAlerta,
    List<FacturaPendienteModel>? facturasPendientes,
    String? fechaConsulta,
    String? origenDatos,
  }) {
    return ResumenDeudaModel(
      codSocio: codSocio ?? this.codSocio,
      suministro: suministro ?? this.suministro,
      moneda: moneda ?? this.moneda,
      saldoPendienteBs: saldoPendienteBs ?? this.saldoPendienteBs,
      cantidadFacturasPendientes:
          cantidadFacturasPendientes ?? this.cantidadFacturasPendientes,
      fechaProximoVencimiento:
          fechaProximoVencimiento ?? this.fechaProximoVencimiento,
      estaVencido: estaVencido ?? this.estaVencido,
      alertaCorte: alertaCorte ?? this.alertaCorte,
      mensajeAlerta: mensajeAlerta ?? this.mensajeAlerta,
      facturasPendientes: facturasPendientes ?? this.facturasPendientes,
      fechaConsulta: fechaConsulta ?? this.fechaConsulta,
      origenDatos: origenDatos ?? this.origenDatos,
    );
  }

  bool get hasDebt => saldoPendienteBs > 0.0 || cantidadFacturasPendientes > 0;

  factory ResumenDeudaModel.fromJson(Map<String, dynamic> json) {
    final rawFacturas = json['facturas_pendientes'];
    List<FacturaPendienteModel> facturasList = [];
    if (rawFacturas is List) {
      facturasList = rawFacturas
          .whereType<Map<String, dynamic>>()
          .map((f) => FacturaPendienteModel.fromJson(f))
          .toList();
    }

    DetalleSuministroModel? detalle;
    if (json['suministro'] is Map<String, dynamic>) {
      detalle = DetalleSuministroModel.fromJson(
        json['suministro'] as Map<String, dynamic>,
      );
    }

    return ResumenDeudaModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      suministro: detalle,
      moneda: json['moneda']?.toString() ?? 'Bs',
      saldoPendienteBs: (json['saldo_pendiente_bs'] as num?)?.toDouble() ?? 0.0,
      cantidadFacturasPendientes:
          (json['cantidad_facturas_pendientes'] as num?)?.toInt() ?? 0,
      fechaProximoVencimiento: json['fecha_proximo_vencimiento']?.toString(),
      estaVencido: json['esta_vencido'] == true,
      alertaCorte: json['alerta_corte'] == true,
      mensajeAlerta: json['mensaje_alerta']?.toString(),
      facturasPendientes: facturasList,
      fechaConsulta: json['fecha_consulta']?.toString(),
      origenDatos: json['origen_datos']?.toString() ?? 'SISTEMA_LEGADO',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      if (suministro != null) 'suministro': suministro!.toJson(),
      'moneda': moneda,
      'saldo_pendiente_bs': saldoPendienteBs,
      'cantidad_facturas_pendientes': cantidadFacturasPendientes,
      'fecha_proximo_vencimiento': fechaProximoVencimiento,
      'esta_vencido': estaVencido,
      'alerta_corte': alertaCorte,
      'mensaje_alerta': mensajeAlerta,
      'facturas_pendientes':
          facturasPendientes.map((f) => f.toJson()).toList(),
      'fecha_consulta': fechaConsulta,
      'origen_datos': origenDatos,
    };
  }
}

/// Estados posibles para una factura en la sección de Deuda:
/// - pagada: Factura cancelada/pagada.
/// - impaga: Factura no pagada regular (si hay <= 2 impagas, o las 2 más recientes si hay > 2).
/// - vencida: Factura con mora que superó el umbral (antiguas si hay más de 2 impagas).
enum EstadoFacturaDeuda {
  pagada,
  impaga,
  vencida,
}

extension DeudaFacturaListExtension on List<FacturaPendienteModel> {
  /// Determina el estado de cobro de cada factura impaga según las reglas de negocio de COSMOL RL:
  /// 1. Si hay más de 2 facturas impagas en total (> 2):
  ///    - Las 2 más recientes cronológicamente se mantienen como 'impaga'.
  ///    - Todas las anteriores (más antiguas) pasan a ser 'vencida'.
  /// 2. Si hay 2 o menos facturas impagas (<= 2):
  ///    - Todas las facturas no pagadas son 'impaga'.
  EstadoFacturaDeuda obtenerEstadoFactura(FacturaPendienteModel factura) {
    if (isEmpty) {
      return EstadoFacturaDeuda.impaga;
    }

    if (length > 2) {
      // Ordenar cronológicamente (más antigua primero, más reciente al final)
      final sortedUnpaid = List<FacturaPendienteModel>.from(this);
      sortedUnpaid.sort((a, b) {
        final cmpAnio = a.anio.compareTo(b.anio);
        if (cmpAnio != 0) return cmpAnio;
        final cmpMes = a.mes.compareTo(b.mes);
        if (cmpMes != 0) return cmpMes;
        final cmpMora = b.diasMora.compareTo(a.diasMora);
        if (cmpMora != 0) return cmpMora;
        return indexOf(a).compareTo(indexOf(b));
      });

      // Las 2 facturas impagas más recientes en el tiempo se mantienen como 'impaga'
      final dosMasRecientes = sortedUnpaid.sublist(sortedUnpaid.length - 2);
      final idxFactura = indexOf(factura);

      final esDeLasDosMasRecientes = dosMasRecientes.any((f) {
        if (identical(f, factura) || f == factura) return true;
        if (idxFactura != -1 && indexOf(f) != idxFactura) return false;
        return f.nroFacip == factura.nroFacip &&
            f.nroFactura == factura.nroFactura &&
            f.periodo == factura.periodo &&
            f.anio == factura.anio &&
            f.mes == factura.mes;
      });

      if (esDeLasDosMasRecientes) {
        return EstadoFacturaDeuda.impaga;
      }

      // Todas las demás impagas antiguas que superan las 2 permitidas pasan a ser 'vencida'
      return EstadoFacturaDeuda.vencida;
    }

    return EstadoFacturaDeuda.impaga;
  }
}
