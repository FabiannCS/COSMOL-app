import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/elegibilidad_reconexion_model.dart';
import '../models/reconexion_tramite_model.dart';
import '../models/solicitud_reconexion_model.dart';

final reconexionRemoteDataSourceProvider = Provider<ReconexionRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ReconexionRemoteDataSource(dio);
});

class ReconexionRemoteDataSource {
  final Dio _dio;

  ReconexionRemoteDataSource(this._dio);

  Future<ElegibilidadReconexionModel> checkElegibilidad(String codSocio) async {
    try {
      final clean = codSocio.trim();
      final response = await _dio.get('/reconexion/elegibilidad/$clean');

      if (response.data is Map<String, dynamic>) {
        return ElegibilidadReconexionModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerException(message: 'Respuesta inválida de verificación de reconexión.');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<ReconexionTramiteModel>> getHistorial(String codSocio) async {
    try {
      final clean = codSocio.trim();
      final response = await _dio.get('/reconexion/historial/$clean');

      if (response.data is List) {
        return (response.data as List)
            .map((e) => ReconexionTramiteModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<String> subirFotoEvidencia({
    required Uint8List bytes,
    required String filename,
    required String codSocio,
  }) async {
    try {
      final formData = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(bytes, filename: filename),
        'cod_socio': codSocio.trim(),
      });

      final response = await _dio.post(
        '/reconexion/subir-foto',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final fotoUrl = data['foto_url'] as String? ?? data['url_proxy'] as String?;
        if (fotoUrl != null && fotoUrl.isNotEmpty) {
          return fotoUrl;
        }
      }
      throw const ServerException(message: 'No se obtuvo la URL de la fotografía cargada.');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<RespuestaSolicitudReconexionModel> solicitarReconexion(
    SolicitudReconexionPayload payload,
  ) async {
    try {
      final response = await _dio.post(
        '/reconexion/solicitar',
        data: payload.toJson(),
      );

      if (response.data is Map<String, dynamic>) {
        return RespuestaSolicitudReconexionModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerException(message: 'Respuesta inválida al registrar la reconexión.');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException e) {
    if (e.response != null && e.response!.data is Map<String, dynamic>) {
      final errorMap = e.response!.data as Map<String, dynamic>;
      final detail = errorMap['detail'] ?? errorMap['mensaje'] ?? errorMap['message'];
      if (detail != null) {
        return ServerException(message: detail.toString());
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkException(message: 'Tiempo de espera agotado al conectar con el servidor.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkException(message: 'Sin conexión a internet. Verifique su red.');
    }
    return ServerException(message: e.message ?? 'Error inesperado de comunicación.');
  }
}
