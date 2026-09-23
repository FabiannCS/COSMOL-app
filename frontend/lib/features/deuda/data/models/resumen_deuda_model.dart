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
