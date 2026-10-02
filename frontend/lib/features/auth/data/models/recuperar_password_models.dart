// Modelos de datos para el flujo de Recuperación de Contraseña / PIN (COSMOL R.L.).
// Alineado con los contratos REST en Docs/backend/guias/PLAN_RECUPERACION_PASSWORD_BACKEND.md

class ValidarTitularResponseModel {
  final String sessionId;
  final String codSocio;
  final String nombreTitular;
  final String telefonoEnmascarado;
  final String mensaje;

  const ValidarTitularResponseModel({
    required this.sessionId,
    required this.codSocio,
    required this.nombreTitular,
    required this.telefonoEnmascarado,
    required this.mensaje,
  });

  factory ValidarTitularResponseModel.fromJson(Map<String, dynamic> json) {
    return ValidarTitularResponseModel(
      sessionId: json['session_id']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString() ?? '',
      nombreTitular: json['nombre_titular']?.toString() ?? '',
      telefonoEnmascarado: json['telefono_enmascarado']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'cod_socio': codSocio,
      'nombre_titular': nombreTitular,
      'telefono_enmascarado': telefonoEnmascarado,
      'mensaje': mensaje,
    };
  }
}

class SolicitarOtpRecuperacionResponseModel {
  final String mensaje;
  final String canal;
  final String telefonoEnmascarado;
  final int ttlSegundos;
  final String? debugCodigoOtp;

  const SolicitarOtpRecuperacionResponseModel({
    required this.mensaje,
    required this.canal,
    required this.telefonoEnmascarado,
    this.ttlSegundos = 300,
    this.debugCodigoOtp,
  });

  factory SolicitarOtpRecuperacionResponseModel.fromJson(Map<String, dynamic> json) {
    return SolicitarOtpRecuperacionResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      canal: json['canal']?.toString() ?? 'WHATSAPP',
      telefonoEnmascarado: json['telefono_enmascarado']?.toString() ?? '',
      ttlSegundos: (json['ttl_segundos'] as num?)?.toInt() ?? 300,
      debugCodigoOtp: json['debug_codigo_otp']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mensaje': mensaje,
      'canal': canal,
      'telefono_enmascarado': telefonoEnmascarado,
      'ttl_segundos': ttlSegundos,
      'debug_codigo_otp': debugCodigoOtp,
    };
  }
}

class VerificarOtpRecuperacionResponseModel {
  final String mensaje;
  final String tokenRecuperacion;
  final String codSocio;

  const VerificarOtpRecuperacionResponseModel({
    required this.mensaje,
    required this.tokenRecuperacion,
    required this.codSocio,
  });

  factory VerificarOtpRecuperacionResponseModel.fromJson(Map<String, dynamic> json) {
    return VerificarOtpRecuperacionResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      tokenRecuperacion: json['token_recuperacion']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mensaje': mensaje,
      'token_recuperacion': tokenRecuperacion,
      'cod_socio': codSocio,
    };
  }
}

class CambiarPinRecuperacionResponseModel {
  final String mensaje;
  final String codSocio;

  const CambiarPinRecuperacionResponseModel({
    required this.mensaje,
    required this.codSocio,
  });

  factory CambiarPinRecuperacionResponseModel.fromJson(Map<String, dynamic> json) {
    return CambiarPinRecuperacionResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mensaje': mensaje,
      'cod_socio': codSocio,
    };
  }
}
