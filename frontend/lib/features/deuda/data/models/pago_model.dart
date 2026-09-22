/// Modelos de datos para Pasarelas de Pago y Conciliación Dinámica (Fase 5 - TASK-05).
class CanalPagoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final String urlRedireccion;
  final String icono;
  final bool soportaQr;
  final bool activo;

  const CanalPagoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.urlRedireccion,
    this.icono = 'qr_code',
    this.soportaQr = true,
    this.activo = true,
  });

  factory CanalPagoModel.fromJson(Map<String, dynamic> json) {
    return CanalPagoModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      urlRedireccion: json['url_redireccion']?.toString() ?? '',
      icono: json['icono']?.toString() ?? 'qr_code',
      soportaQr: json['soporta_qr'] == true,
      activo: json['activo'] == true || json['activo'] == null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'url_redireccion': urlRedireccion,
      'icono': icono,
      'soporta_qr': soportaQr,
      'activo': activo,
    };
  }
}

class CanalesPagoResponseModel {
  final String codSocio;
  final String nombreTitular;
  final double totalDeudaBs;
  final int cantFacturasPendientes;
  final List<CanalPagoModel> canales;
  final String mensajeAyuda;
  final DateTime? fechaConsulta;

  const CanalesPagoResponseModel({
    required this.codSocio,
    required this.nombreTitular,
    required this.totalDeudaBs,
    required this.cantFacturasPendientes,
    required this.canales,
    required this.mensajeAyuda,
    this.fechaConsulta,
  });

  factory CanalesPagoResponseModel.fromJson(Map<String, dynamic> json) {
    List<CanalPagoModel> canalesList = [];
    if (json['canales'] is List) {
      canalesList = (json['canales'] as List)
          .whereType<Map<String, dynamic>>()
          .map((c) => CanalPagoModel.fromJson(c))
          .toList();
    }

    return CanalesPagoResponseModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      nombreTitular: json['nombre_titular']?.toString() ?? '',
      totalDeudaBs: (json['total_deuda_bs'] is num)
          ? (json['total_deuda_bs'] as num).toDouble()
          : double.tryParse(json['total_deuda_bs']?.toString() ?? '0.0') ?? 0.0,
      cantFacturasPendientes: json['cant_facturas_pendientes'] is int
          ? json['cant_facturas_pendientes'] as int
          : int.tryParse(json['cant_facturas_pendientes']?.toString() ?? '0') ?? 0,
      canales: canalesList,
      mensajeAyuda: json['mensaje_ayuda']?.toString() ?? '',
      fechaConsulta: json['fecha_consulta'] != null
          ? DateTime.tryParse(json['fecha_consulta'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      'nombre_titular': nombreTitular,
      'total_deuda_bs': totalDeudaBs,
      'cant_facturas_pendientes': cantFacturasPendientes,
      'canales': canales.map((c) => c.toJson()).toList(),
      'mensaje_ayuda': mensajeAyuda,
      'fecha_consulta': fechaConsulta?.toIso8601String(),
    };
  }
}

class RegistrarIntentoPagoResponseModel {
  final bool exito;
  final String codSocio;
  final String canalId;
  final String mensaje;
  final String urlRedireccion;
  final bool ventanaVerificacionActiva;
  final int tiempoExpiracionSegundos;

  const RegistrarIntentoPagoResponseModel({
    required this.exito,
    required this.codSocio,
    required this.canalId,
    required this.mensaje,
    required this.urlRedireccion,
    this.ventanaVerificacionActiva = true,
    this.tiempoExpiracionSegundos = 900,
  });

  factory RegistrarIntentoPagoResponseModel.fromJson(Map<String, dynamic> json) {
    return RegistrarIntentoPagoResponseModel(
      exito: json['exito'] == true,
      codSocio: json['cod_socio']?.toString() ?? '',
      canalId: json['canal_id']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      urlRedireccion: json['url_redireccion']?.toString() ?? '',
      ventanaVerificacionActiva: json['ventana_verificacion_activa'] == true,
      tiempoExpiracionSegundos: json['tiempo_expiracion_segundos'] is int
          ? json['tiempo_expiracion_segundos'] as int
          : int.tryParse(json['tiempo_expiracion_segundos']?.toString() ?? '900') ?? 900,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exito': exito,
      'cod_socio': codSocio,
      'canal_id': canalId,
      'mensaje': mensaje,
      'url_redireccion': urlRedireccion,
      'ventana_verificacion_activa': ventanaVerificacionActiva,
      'tiempo_expiracion_segundos': tiempoExpiracionSegundos,
    };
  }
}

class EstadoVerificacionPagoModel {
  final String codSocio;
  final bool deudaSaldada;
  final double saldoActualBs;
  final int cantFacturasPendientes;
  final String mensaje;
  final bool ventanaActiva;

  const EstadoVerificacionPagoModel({
    required this.codSocio,
    required this.deudaSaldada,
    required this.saldoActualBs,
    required this.cantFacturasPendientes,
    required this.mensaje,
    required this.ventanaActiva,
  });

  factory EstadoVerificacionPagoModel.fromJson(Map<String, dynamic> json) {
    return EstadoVerificacionPagoModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      deudaSaldada: json['deuda_saldada'] == true,
      saldoActualBs: (json['saldo_actual_bs'] is num)
          ? (json['saldo_actual_bs'] as num).toDouble()
          : double.tryParse(json['saldo_actual_bs']?.toString() ?? '0.0') ?? 0.0,
      cantFacturasPendientes: json['cant_facturas_pendientes'] is int
          ? json['cant_facturas_pendientes'] as int
          : int.tryParse(json['cant_facturas_pendientes']?.toString() ?? '0') ?? 0,
      mensaje: json['mensaje']?.toString() ?? '',
      ventanaActiva: json['ventana_activa'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      'deuda_saldada': deudaSaldada,
      'saldo_actual_bs': saldoActualBs,
      'cant_facturas_pendientes': cantFacturasPendientes,
      'mensaje': mensaje,
      'ventana_activa': ventanaActiva,
    };
  }
}
