import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/error_parser.dart';
import '../../../../core/network/api_client.dart';
import '../models/deuda_response_model.dart';

final deudaRemoteDataSourceProvider = Provider<DeudaRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DeudaRemoteDataSource(dio);
});

class DeudaRemoteDataSource {
  final Dio _dio;

  DeudaRemoteDataSource(this._dio);

  /// Consulta en tiempo real la deuda y facturas pendientes del suministro.
  /// Llama al endpoint oficial del backend BFF `/api/v1/deuda/{cod_socio}`.
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();
      final response = await _dio.get(
        '/deuda/$cleanCodSocio',
        queryParameters: {
          if (forzarRefresco) 'forzar_refresco': true,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return ResumenDeudaModel.fromJson(response.data as Map<String, dynamic>);
      }

      throw Exception('Formato de respuesta inesperado al consultar deuda.');
    } catch (e) {
      throw ErrorParser.parse(e);
    }
  }
}
