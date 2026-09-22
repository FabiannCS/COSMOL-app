import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/resumen_deuda_model.dart';

final deudaRemoteDataSourceProvider = Provider<DeudaRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DeudaRemoteDataSource(dio);
});

class DeudaRemoteDataSource {
  final Dio _dio;

  DeudaRemoteDataSource(this._dio);

  /// Consulta la deuda y facturas impagas de un suministro en tiempo real.
  /// Llama al endpoint `/api/v1/deuda/{cod_socio}` del BFF FastAPI.
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _dio.get(
        '/deuda/$cleanCodSocio',
        queryParameters: {
          'forzar_refresco': forzarRefresco,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return ResumenDeudaModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const ServerException(
        message: 'Respuesta de deuda inválida del servidor.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Invalida la caché de deuda en Redis para forzar lectura fresca
  Future<void> invalidarCacheDeuda({required String codSocio}) async {
    try {
      final cleanCodSocio = codSocio.trim();
      await _dio.post('/deuda/$cleanCodSocio/invalidar-cache');
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
          return ValidationException(
            message: errMap['message']?.toString() ?? 'Error en consulta de deuda',
            code: errMap['code']?.toString(),
          );
        } else if (data['detail'] != null) {
          return ValidationException(
            message: data['detail'].toString(),
          );
        }
      }
    }

    return ServerException(
      message: 'Error al consultar el saldo de deuda (${response?.statusCode ?? 500})',
    );
  }
}
