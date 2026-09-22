import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/consumo_factura_model.dart';

final consumoRemoteDataSourceProvider =
    Provider<ConsumoRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ConsumoRemoteDataSource(dio);
});

class ConsumoRemoteDataSource {
  final Dio _dio;

  ConsumoRemoteDataSource(this._dio);

  /// Consulta el historial completo de consumo y analítica para el código de socio.
  /// Conecta con el endpoint oficial del BFF FastAPI: `GET /api/v1/consumo/{cod_socio}`
  Future<HistorialConsumoModel> obtenerHistorialConsumo({
    required String codSocio,
    bool forzarRefresco = false,
    int meses = 12,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();

      final response = await _dio.get(
        '/consumo/$cleanCodSocio',
        queryParameters: {
          'meses': meses,
          'forzar_refresco': forzarRefresco,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return HistorialConsumoModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const ServerException(
        message: 'Respuesta inválida del servidor de consumo.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Error inesperado: ${e.toString()}');
    }
  }

  /// Invalida manualmente la clave de caché en Redis para forzar lectura fresca
  Future<bool> invalidarCacheConsumo({required String codSocio}) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _dio.post('/consumo/$cleanCodSocio/invalidar-cache');
      if (response.data is Map<String, dynamic>) {
        return response.data['cache_invalidada'] == true;
      }
      return true;
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
      return const NetworkException(
        message: 'No se pudo conectar con el servidor de COSMOL. Verifique su conexión a internet.',
      );
    }

    final response = e.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] is Map<String, dynamic>) {
          final errMap = data['error'] as Map<String, dynamic>;
          final message = errMap['message']?.toString() ?? 'Error en la solicitud';
          final code = errMap['code']?.toString();
          final details = errMap['details'] as Map<String, dynamic>?;

          return ValidationException(
            message: message,
            code: code,
            details: details,
          );
        } else if (data['detail'] != null) {
          final detail = data['detail'];
          if (detail is String) {
            return ValidationException(message: detail);
          } else if (detail is Map<String, dynamic> && detail['message'] != null) {
            return ValidationException(message: detail['message'].toString());
          }
        } else if (data['mensaje'] != null) {
          return ValidationException(
            message: data['mensaje'].toString(),
          );
        }
      }
    }

    if (response?.statusCode == 403) {
      return const ValidationException(
        message: 'No tiene permisos para consultar el historial de este suministro o no está vinculado a su cuenta.',
        code: 'SUPPLY_ACCESS_DENIED',
      );
    }

    if (response?.statusCode == 404) {
      return const ValidationException(
        message: 'No se encontraron registros de historial de consumo para este suministro.',
      );
    }

    return ServerException(
      message: 'Error de comunicación con el servidor (${response?.statusCode ?? 500})',
    );
  }
}
