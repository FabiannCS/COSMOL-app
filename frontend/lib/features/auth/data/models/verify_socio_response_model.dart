/// DTO para la respuesta de verificación de socio en COSMOL
class VerifySocioResponseModel {
  final String codSocio;
  final String nombreTitular;
  final bool cuentaExistente;
  final String? telefonoEnmascarado;
  final String mensaje;

  const VerifySocioResponseModel({
    required this.codSocio,
    required this.nombreTitular,
    this.cuentaExistente = false,
    this.telefonoEnmascarado,
    required this.mensaje,
  });

  factory VerifySocioResponseModel.fromJson(Map<String, dynamic> json) {
    return VerifySocioResponseModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      nombreTitular: json['nombre_titular']?.toString() ?? '',
      cuentaExistente: json['cuenta_existente'] as bool? ?? false,
      telefonoEnmascarado: json['telefono_enmascarado']?.toString(),
      mensaje: json['mensaje']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cod_socio': codSocio,
      'nombre_titular': nombreTitular,
      'cuenta_existente': cuentaExistente,
      if (telefonoEnmascarado != null) 'telefono_enmascarado': telefonoEnmascarado,
      'mensaje': mensaje,
    };
  }
}
