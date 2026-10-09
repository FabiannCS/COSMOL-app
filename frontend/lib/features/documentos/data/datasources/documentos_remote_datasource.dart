import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/app_config.dart';
import '../models/documento_model.dart';
import '../models/historial_factura_item_model.dart';

final legacyDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.cosmolLegacyUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Accept': 'application/json',
      },
    ),
  );
});

final documentosRemoteDataSourceProvider =
    Provider<DocumentosRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  final legacyDio = ref.watch(legacyDioProvider);
  return DocumentosRemoteDataSource(dio, legacyDio: legacyDio);
});

class DocumentosRemoteDataSource {
  final Dio _dio;
  final Dio _legacyDio;

  DocumentosRemoteDataSource(
    this._dio, {
    Dio? legacyDio,
  }) : _legacyDio = legacyDio ?? _dio;

  /// Consulta la colección organizada de documentos para un código de socio.
  /// Conecta con el endpoint oficial: `GET /api/v1/documentos/{cod_socio}`
  Future<ListaDocumentosModel> obtenerDocumentos({
    required String codSocio,
    String? tipo,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final Map<String, dynamic> queryParams = {};
      if (tipo != null && tipo.trim().isNotEmpty) {
        queryParams['tipo'] = tipo.trim();
      }

      final response = await _dio.get(
        '/documentos/$cleanCodSocio',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.data is Map<String, dynamic>) {
        return ListaDocumentosModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }

      throw const ServerException(
        message: 'Respuesta inválida del servidor al listar documentos.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Error inesperado: ${e.toString()}');
    }
  }

  /// Descarga el flujo de bytes binarios del PDF desde MinIO S3 vía streaming.
  /// Conecta con el endpoint oficial: `GET /api/v1/documentos/{doc_id}/descargar`
  Future<Uint8List> descargarPdfBytes({
    required String docId,
  }) async {
    try {
      final cleanDocId = docId.trim();

      final response = await _dio.get<List<int>>(
        '/documentos/$cleanDocId/descargar',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf',
          },
        ),
      );

      if (response.data != null && response.data is List<int>) {
        return Uint8List.fromList(response.data!);
      }

      throw const ServerException(
        message: 'El servidor no devolvió los datos binarios del archivo PDF.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Error al descargar PDF: ${e.toString()}');
    }
  }

  /// Consulta el historial cronológico de los últimos 12 meses de facturación del socio.
  /// Conecta con el endpoint oficial: `GET /socios/{cod_socio}/historial-facturas`
  Future<List<HistorialFacturaItemModel>> obtenerHistorial12Meses({
    required String codSocio,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _legacyDio.get('/socios/$cleanCodSocio/historial-facturas');

      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        if (map['estado'] == 'exito' && map['datos'] is List) {
          final list = map['datos'] as List;
          return list
              .whereType<Map<String, dynamic>>()
              .map((item) => HistorialFacturaItemModel.fromJson(item))
              .toList();
        }
        return [];
      }

      throw const ServerException(
        message: 'Respuesta inválida del servidor al consultar historial de facturas.',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(message: 'Error al obtener historial de facturas: ${e.toString()}');
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
        message: 'Acceso denegado: este documento fiscal está reservado exclusivamente para el titular.',
        code: 'DOCUMENT_ACCESS_DENIED',
      );
    }

    if (response?.statusCode == 404) {
      return const ValidationException(
        message: 'El documento o factura solicitada no fue encontrada.',
        code: 'DOCUMENTO_NOT_FOUND',
      );
    }

    return ServerException(
      message: 'Error de comunicación con el servidor (${response?.statusCode ?? 500})',
    );
  }
}
