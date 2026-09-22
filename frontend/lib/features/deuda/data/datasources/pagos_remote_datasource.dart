import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/pago_model.dart';

final pagosRemoteDataSourceProvider = Provider<PagosRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return PagosRemoteDataSource(dio);
});

class PagosRemoteDataSource {
  final Dio _dio;

  PagosRemoteDataSource(this._dio);

  /// Consulta los canales y pasarelas de pago oficiales para un socio.
  /// Llama al endpoint `GET /api/v1/pagos/canales/{cod_socio}`
  Future<CanalesPagoResponseModel> obtenerCanalesPago({
    required String codSocio,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _dio.get('/pagos/canales/$cleanCodSocio');

      if (response.data is Map<String, dynamic>) {
        return CanalesPagoResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const ServerException(
        message: 'Respuesta inválida del servidor al consultar canales de pago.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Registra la intención de pago e inicia la ventana de verificación en Redis.
  /// Llama al endpoint `POST /api/v1/pagos/registrar-intento/{cod_socio}`
  Future<RegistrarIntentoPagoResponseModel> registrarIntentoPago({
    required String codSocio,
    required String canalId,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _dio.post(
        '/pagos/registrar-intento/$cleanCodSocio',
        data: {'canal_id': canalId.trim()},
      );

      if (response.data is Map<String, dynamic>) {
        return RegistrarIntentoPagoResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const ServerException(
        message: 'Respuesta inválida al registrar la intención de pago.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Verifica en vivo si la deuda fue saldada en el sistema comercial Informix.
  /// Llama al endpoint `GET /api/v1/pagos/verificar-estado/{cod_socio}`
  Future<EstadoVerificacionPagoModel> verificarEstadoPago({
    required String codSocio,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _dio.get('/pagos/verificar-estado/$cleanCodSocio');

      if (response.data is Map<String, dynamic>) {
        return EstadoVerificacionPagoModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const ServerException(
        message: 'Respuesta inválida al verificar el estado del pago.',
      );
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
        message: 'No se pudo conectar con el servidor para gestionar el pago.',
      );
    }

    final response = e.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] is Map<String, dynamic>) {
          final errMap = data['error'] as Map<String, dynamic>;
          return ValidationException(
            message: errMap['message']?.toString() ?? 'Error al procesar el pago',
            code: errMap['code']?.toString(),
          );
        } else if (data['detail'] != null) {
          return ValidationException(message: data['detail'].toString());
        } else if (data['mensaje'] != null) {
          return ValidationException(message: data['mensaje'].toString());
        }
      }
    }

    return ServerException(
      message: 'Error al conectar con la pasarela de pagos (${response?.statusCode ?? 500})',
    );
  }
}
