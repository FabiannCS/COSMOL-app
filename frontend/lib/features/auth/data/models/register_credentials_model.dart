/// DTO para el registro final de credenciales y PIN
class RegisterCredentialsRequestModel {
  final String telefono;
  final String tokenOtpValido;
  final String nuevoPin;
  final String? codSocio;
  final String? ci;
  final String? username;

  const RegisterCredentialsRequestModel({
    required this.telefono,
    required this.tokenOtpValido,
    required this.nuevoPin,
    this.codSocio,
    this.ci,
    this.username,
  });

  Map<String, dynamic> toJson() {
    return {
      'telefono': telefono,
      'token_otp_valido': tokenOtpValido,
      'nuevo_pin': nuevoPin,
      if (codSocio != null) 'cod_socio': codSocio,
      if (ci != null) 'ci': ci,
      if (username != null) 'username': username,
    };
  }
}

class RegisterCredentialsResponseModel {
  final String mensaje;
  final String? codSocio;

  const RegisterCredentialsResponseModel({
    required this.mensaje,
    this.codSocio,
  });

  factory RegisterCredentialsResponseModel.fromJson(Map<String, dynamic> json) {
    return RegisterCredentialsResponseModel(
      mensaje: json['mensaje']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString(),
    );
  }
}
