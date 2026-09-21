import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/login_response_model.dart';

final multicuentaRemoteDataSourceProvider =
    Provider<MulticuentaRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return MulticuentaRemoteDataSource(dio);
});

class MulticuentaRemoteDataSource {
  final Dio _dio;

  MulticuentaRemoteDataSource(this._dio);

  /// Obtiene la lista de suministros vinculados al socio autenticado
  Future<List<SuministroModel>> listarSuministros() async {
    try {
      final response = await _dio.get('/autenticacion/suministros');
      final rawList = response.data as List<dynamic>? ?? [];
      return rawList
          .map((item) => SuministroModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Vincula un nuevo código de suministro en Modo Titular o Modo Consulta/Pago
  Future<SuministroModel> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) async {
    try {
      final response = await _dio.post(
        '/autenticacion/suministros/vincular',
        data: {
          'cod_socio': codSocio.trim(),
          if (ciOMedidor != null && ciOMedidor.trim().isNotEmpty)
            'ci_o_medidor': ciOMedidor.trim(),
          'alias': alias.trim().isNotEmpty ? alias.trim() : 'Mi Suministro',
        },
      );
      return SuministroModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException e) {
    if (e.error is AppException) {
      return e.error as AppException;
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final response = e.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] is Map<String, dynamic>) {
          final errMap = data['error'] as Map<String, dynamic>;
          final message =
              errMap['message']?.toString() ?? 'Error en la solicitud';
          final code = errMap['code']?.toString();
          final details = errMap['details'] as Map<String, dynamic>?;

          return ValidationException(
            message: message,
            code: code,
            details: details,
          );
        } else if (data['detail'] != null) {
          return ValidationException(
            message: data['detail'].toString(),
          );
        }
      }
    }

    return ServerException(
      message:
          'Error de comunicación con el servidor (${response?.statusCode ?? 500})',
    );
  }
}
