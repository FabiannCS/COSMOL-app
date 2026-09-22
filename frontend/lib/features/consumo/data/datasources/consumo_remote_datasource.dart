import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/error_parser.dart';
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

  /// Consulta el historial de facturas y consumo para el código de socio.
  /// Conecta con el endpoint oficial del BFF `/api/v1/consumo/{cod_socio}`.
  Future<List<ConsumoFacturaModel>> obtenerHistorialFacturas({
    required String codSocio,
    String? ci,
  }) async {
    try {
      final cleanCodSocio = codSocio.trim();

      final response = await _dio.get(
        '/consumo/$cleanCodSocio',
        queryParameters: {'meses': 12},
      );

      if (response.data is Map<String, dynamic>) {
        final parsed = ConsumoHistorialResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
        return parsed.datos;
      } else if (response.data is List) {
        final list = response.data as List;
        return list
            .whereType<Map<String, dynamic>>()
            .map((item) => ConsumoFacturaModel.fromJson(item))
            .toList();
      }

      return [];
    } catch (e) {
      throw ErrorParser.parse(e);
    }
  }
}
