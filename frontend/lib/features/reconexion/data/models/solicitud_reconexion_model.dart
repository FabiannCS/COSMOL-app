class SolicitudReconexionPayload {
  final String codigoSocio;
  final int idTipoReconexion;
  final String coordenadasGps;
  final String glosa;
  final String? fotoUrl;

  const SolicitudReconexionPayload({
    required this.codigoSocio,
    required this.idTipoReconexion,
    required this.coordenadasGps,
    required this.glosa,
    this.fotoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'codigo_socio': codigoSocio,
      'id_tipo_reconexion': idTipoReconexion,
      'coordenadas_gps': coordenadasGps,
      'glosa': glosa,
      'foto_url': fotoUrl,
    };
  }
}

class RespuestaSolicitudReconexionModel {
  final int idReconexion;
  final String estado;
  final int facturasPendientes;
  final String mensaje;

  const RespuestaSolicitudReconexionModel({
    required this.idReconexion,
    required this.estado,
    required this.facturasPendientes,
    required this.mensaje,
  });

  factory RespuestaSolicitudReconexionModel.fromJson(Map<String, dynamic> json) {
    return RespuestaSolicitudReconexionModel(
      idReconexion: (json['id_reconexion'] as num?)?.toInt() ?? 0,
      estado: (json['estado'] as String? ?? 'PENDIENTE').toUpperCase(),
      facturasPendientes: (json['facturas_pendientes'] as num?)?.toInt() ?? 0,
      mensaje: json['mensaje'] as String? ?? 'Solicitud registrada.',
    );
  }
}

