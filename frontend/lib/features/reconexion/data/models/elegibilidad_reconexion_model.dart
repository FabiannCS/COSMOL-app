class ElegibilidadReconexionModel {
  final String codigoSocio;
  final bool esElegible;
  final String? motivoBloqueo;
  final String mensajeUsuario;
  final int facturasPendientes;
  final double totalDeudaBs;
  final int? tramitePendienteId;
  final String? ubicacionCatastral;
  final int? zona;
  final int? ruta;
  final String? nombres;

  const ElegibilidadReconexionModel({
    required this.codigoSocio,
    required this.esElegible,
    this.motivoBloqueo,
    required this.mensajeUsuario,
    this.facturasPendientes = 0,
    this.totalDeudaBs = 0.0,
    this.tramitePendienteId,
    this.ubicacionCatastral,
    this.zona,
    this.ruta,
    this.nombres,
  });

  factory ElegibilidadReconexionModel.fromJson(Map<String, dynamic> json) {
    return ElegibilidadReconexionModel(
      codigoSocio: (json['codigo_socio'] ?? '').toString(),
      esElegible: json['es_elegible'] as bool? ?? false,
      motivoBloqueo: json['motivo_bloqueo'] as String?,
      mensajeUsuario: json['mensaje_usuario'] as String? ?? '',
      facturasPendientes: (json['facturas_pendientes'] as num?)?.toInt() ?? 0,
      totalDeudaBs: (json['total_deuda_bs'] as num?)?.toDouble() ?? 0.0,
      tramitePendienteId: (json['tramite_pendiente_id'] as num?)?.toInt(),
      ubicacionCatastral: json['ubicacion_catastral'] as String?,
      zona: (json['zona'] as num?)?.toInt(),
      ruta: (json['ruta'] as num?)?.toInt(),
      nombres: json['nombres'] as String?,
    );
  }
}

