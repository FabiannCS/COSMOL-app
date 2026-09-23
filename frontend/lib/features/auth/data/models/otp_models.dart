/// Modelos DTO para solicitud y verificación de OTP Dual (WhatsApp/SMS)
class OtpRequestModel {
  final String codSocio;
  final String telefono;
  final String canal; // WHATSAPP o SMS

  const OtpRequestModel({
    required this.codSocio,
    required this.telefono,
    this.canal = 'WHATSAPP',
  });

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      'telefono': telefono,
      'canal': canal,
    };
  }
}

class OtpResponseModel {
  final String mensaje;
  final String canal;
  final String telefonoEnmascarado;
  final int ttlSegundos;
  final String? debugCodigoOtp;

  const OtpResponseModel({
    required this.mensaje,
    required this.canal,
    required this.telefonoEnmascarado,
    required this.ttlSegundos,
    this.debugCodigoOtp,
  });

  factory OtpResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      canal: json['canal']?.toString() ?? 'WHATSAPP',
      telefonoEnmascarado: json['telefono_enmascarado']?.toString() ?? '',
      ttlSegundos: (json['ttl_segundos'] as num?)?.toInt() ?? 300,
      debugCodigoOtp: json['debug_codigo_otp']?.toString(),
    );
  }
}

class VerifyOtpResponseModel {
  final String mensaje;
  final String tokenOtpValido;
  final String? codSocio;

  const VerifyOtpResponseModel({
    required this.mensaje,
    required this.tokenOtpValido,
    this.codSocio,
  });

  factory VerifyOtpResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      tokenOtpValido: json['token_otp_valido']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString(),
    );
  }
}
