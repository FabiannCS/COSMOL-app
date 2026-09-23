/// DTOs para la autenticación y lista de suministros
class SuministroModel {
  final String id;
  final String codSocio;
  final String alias;
  final String rol;
  final bool esSuministroPrincipal;

  const SuministroModel({
    required this.id,
    required this.codSocio,
    required this.alias,
    required this.rol,
    required this.esSuministroPrincipal,
  });

  factory SuministroModel.fromJson(Map<String, dynamic> json) {
    return SuministroModel(
      id: json['id']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString() ?? '',
      alias: json['alias']?.toString() ?? '',
      rol: json['rol']?.toString() ?? 'TITULAR',
      esSuministroPrincipal: json['es_suministro_principal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cod_socio': codSocio,
      'alias': alias,
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

  const LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.suministros,
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
    );
  }
}
