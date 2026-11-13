enum TipoNotificacion {
  avisoCorte,
  facturaVencida,
  facturaImpaga,
  reconexion,
  multicuenta,
  alDia,
  avisoGeneral,
}

enum NotificacionAccionTipo {
  pagar,
  verReconexion,
  cambiarSuministro,
  ninguno,
}

class NotificacionItemModel {
  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String mensaje;
  final DateTime fechaHora;
  final bool esLeida;
  final bool esUrgente;
  final NotificacionAccionTipo accionTipo;
  final String? accionPayload;
  final String? codSocio;

  const NotificacionItemModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.fechaHora,
    this.esLeida = false,
    this.esUrgente = false,
    this.accionTipo = NotificacionAccionTipo.ninguno,
    this.accionPayload,
    this.codSocio,
  });

  NotificacionItemModel copyWith({
    String? id,
    TipoNotificacion? tipo,
    String? titulo,
    String? mensaje,
    DateTime? fechaHora,
    bool? esLeida,
    bool? esUrgente,
    NotificacionAccionTipo? accionTipo,
    String? accionPayload,
    String? codSocio,
  }) {
    return NotificacionItemModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      fechaHora: fechaHora ?? this.fechaHora,
      esLeida: esLeida ?? this.esLeida,
      esUrgente: esUrgente ?? this.esUrgente,
      accionTipo: accionTipo ?? this.accionTipo,
      accionPayload: accionPayload ?? this.accionPayload,
      codSocio: codSocio ?? this.codSocio,
    );
  }
}
