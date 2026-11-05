/// DTOs para la autenticación y lista de suministros
class SuministroModel {
  final String id;
  final String codSocio;
  final String alias;
  final String? nombre;
  final String rol;
  final bool esSuministroPrincipal;

  const SuministroModel({
    required this.id,
    required this.codSocio,
    required this.alias,
    this.nombre,
    required this.rol,
    required this.esSuministroPrincipal,
  });

  factory SuministroModel.fromJson(Map<String, dynamic> json) {
    return SuministroModel(
      id: json['id']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString() ?? '',
      alias: json['alias']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? json['nombre_titular']?.toString(),
      rol: json['rol']?.toString() ?? 'TITULAR',
      esSuministroPrincipal: json['es_suministro_principal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cod_socio': codSocio,
      'alias': alias,
      if (nombre != null) 'nombre': nombre,
      'rol': rol,
      'es_suministro_principal': esSuministroPrincipal,
    };
  }
}

class LoginResponseModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final List<SuministroModel> suministros;
  final bool requiereTransferencia;
  final String? sessionTransferId;
  final String? dispositivoAnteriorModelo;
  final String? telefonoEnmascarado;
  final String? mensaje;

  const LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.suministros,
    this.requiereTransferencia = false,
    this.sessionTransferId,
    this.dispositivoAnteriorModelo,
    this.telefonoEnmascarado,
    this.mensaje,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final rawSuministros = json['suministros'] as List<dynamic>? ?? [];
    return LoginResponseModel(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      suministros: rawSuministros
          .map((item) => SuministroModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      requiereTransferencia: json['requiere_transferencia'] as bool? ?? false,
      sessionTransferId: json['session_transfer_id']?.toString(),
      dispositivoAnteriorModelo: json['dispositivo_anterior_modelo']?.toString(),
      telefonoEnmascarado: json['telefono_enmascarado']?.toString(),
      mensaje: json['mensaje']?.toString(),
    );
  }
}

class TransferenciaSolicitarOtpResponseModel {
  final String sessionTransferId;
  final String mensaje;
  final String telefonoEnmascarado;
  final int ttlSegundos;
  final String? debugCodigoOtp;

  const TransferenciaSolicitarOtpResponseModel({
    required this.sessionTransferId,
    required this.mensaje,
    required this.telefonoEnmascarado,
    this.ttlSegundos = 300,
    this.debugCodigoOtp,
  });

  factory TransferenciaSolicitarOtpResponseModel.fromJson(Map<String, dynamic> json) {
    return TransferenciaSolicitarOtpResponseModel(
      sessionTransferId: json['session_transfer_id']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      telefonoEnmascarado: json['telefono_enmascarado']?.toString() ?? '',
      ttlSegundos: (json['ttl_segundos'] as num?)?.toInt() ?? 300,
      debugCodigoOtp: json['debug_codigo_otp']?.toString(),
    );
  }
}
