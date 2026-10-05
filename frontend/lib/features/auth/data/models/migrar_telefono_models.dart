import 'login_response_model.dart';

/// Petición para iniciar la migración de teléfono
class MigrarTelefonoIniciarRequestModel {
  final String codSocio;
  final String ci;
  final String pinActual;
  final String nuevoTelefono;
  final String canal;

  const MigrarTelefonoIniciarRequestModel({
    required this.codSocio,
    required this.ci,
    required this.pinActual,
    required this.nuevoTelefono,
    this.canal = 'WHATSAPP',
  });

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio.trim(),
      'ci': ci.trim(),
      'pin_actual': pinActual.trim(),
      'nuevo_telefono': nuevoTelefono.trim(),
      'canal': canal.toUpperCase(),
    };
  }
}

/// Respuesta de inicio de migración
class MigrarTelefonoIniciarResponseModel {
  final String sessionId;
  final String mensaje;
  final int ttlSegundos;
  final String? debugCodigoOtp;

  const MigrarTelefonoIniciarResponseModel({
    required this.sessionId,
    required this.mensaje,
    required this.ttlSegundos,
    this.debugCodigoOtp,
  });

  factory MigrarTelefonoIniciarResponseModel.fromJson(Map<String, dynamic> json) {
    return MigrarTelefonoIniciarResponseModel(
      sessionId: json['session_id']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      ttlSegundos: (json['ttl_segundos'] as num?)?.toInt() ?? 300,
      debugCodigoOtp: json['debug_codigo_otp']?.toString(),
    );
  }
}

/// Petición para confirmar la migración con OTP
class MigrarTelefonoConfirmarRequestModel {
  final String sessionId;
  final String codigoOtp;

  const MigrarTelefonoConfirmarRequestModel({
    required this.sessionId,
    required this.codigoOtp,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId.trim(),
      'codigo_otp': codigoOtp.trim(),
    };
  }
}

/// Respuesta al confirmar la migración (incluye nuevos tokens de sesión)
class MigrarTelefonoConfirmarResponseModel {
  final String mensaje;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String codSocio;
  final String nombre;
  final List<SuministroModel> suministros;

  const MigrarTelefonoConfirmarResponseModel({
    required this.mensaje,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.codSocio,
    required this.nombre,
    required this.suministros,
  });

  factory MigrarTelefonoConfirmarResponseModel.fromJson(Map<String, dynamic> json) {
    final rawSuministros = json['suministros'] as List<dynamic>? ?? [];
    return MigrarTelefonoConfirmarResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      codSocio: json['cod_socio']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      suministros: rawSuministros
          .map((item) => SuministroModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  LoginResponseModel toLoginResponseModel() {
    return LoginResponseModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      suministros: suministros,
    );
  }
}
