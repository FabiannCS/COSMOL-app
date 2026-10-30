class ReconexionTramiteModel {
  final int idReconexion;
  final String? fecha;
  final String? tipo;
  final String estado;
  final String? glosa;

  const ReconexionTramiteModel({
    required this.idReconexion,
    this.fecha,
    this.tipo,
    required this.estado,
    this.glosa,
  });

  factory ReconexionTramiteModel.fromJson(Map<String, dynamic> json) {
    return ReconexionTramiteModel(
      idReconexion: (json['id_reconexion'] as num?)?.toInt() ?? 0,
      fecha: json['fecha']?.toString(),
      tipo: json['tipo']?.toString() ??
          json['id_tipo_reconexion']?.toString() ??
          json['tipo_reconexion']?.toString(),
      estado: (json['estado'] as String? ?? 'DESCONOCIDO').toUpperCase(),
      glosa: json['glosa']?.toString(),
    );
  }

  bool get isPendiente => estado == 'PENDIENTE';
  bool get isEnProceso => estado == 'EN_PROCESO';
  bool get isFinalizado => estado == 'FINALIZADO' || estado == 'EJECUTADO';
  bool get isRechazado => estado == 'ANULADO' || estado == 'RECHAZADO';

  String get tipoFormateado {
    final raw = (tipo ?? '').trim().toLowerCase();
    if (raw == '1' || raw == 'corte normal' || raw.contains('normal')) {
      return 'Reconexión normal';
    }
    if (raw == '2' || raw.contains('con medidor') || raw.contains('medidor')) {
      return 'Reconexión con medidor';
    }
    if (raw == '3' || raw.contains('material')) {
      return 'Reconexión con material';
    }
    if (raw == '4' || raw.contains('otro')) {
      return 'Otros motivos';
    }
    if (tipo != null && tipo!.trim().isNotEmpty) {
      return tipo!.trim();
    }
    return 'Reconexión normal';
  }
}
