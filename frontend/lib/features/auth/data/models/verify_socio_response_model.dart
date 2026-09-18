/// DTO para la respuesta de verificación de socio en COSMOL
class VerifySocioResponseModel {
  final String codSocio;
  final String nombreTitular;
  final String mensaje;

  const VerifySocioResponseModel({
    required this.codSocio,
    required this.nombreTitular,
    required this.mensaje,
  });

  factory VerifySocioResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifySocioResponseModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      nombreTitular: json['nombre_titular']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      'nombre_titular': nombreTitular,
      'mensaje': mensaje,
    };
  }
}
