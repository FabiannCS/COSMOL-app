import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/consumo_repository.dart';
import '../datasources/consumo_remote_datasource.dart';
import '../models/consumo_factura_model.dart';

final consumoRepositoryProvider = Provider<ConsumoRepository>((ref) {
  final remoteDataSource = ref.watch(consumoRemoteDataSourceProvider);
  return ConsumoRepositoryImpl(remoteDataSource);
});

class ConsumoRepositoryImpl implements ConsumoRepository {
  final ConsumoRemoteDataSource remoteDataSource;

  ConsumoRepositoryImpl(this.remoteDataSource);

  @override
  Future<HistorialConsumoModel> obtenerHistorialConsumo({
    required String codSocio,
    bool forzarRefresco = false,
    int meses = 12,
  }) {
    return remoteDataSource.obtenerHistorialConsumo(
      codSocio: codSocio,
      forzarRefresco: forzarRefresco,
      meses: meses,
    );
  }

  @override
  Future<bool> invalidarCacheConsumo({required String codSocio}) {
    return remoteDataSource.invalidarCacheConsumo(codSocio: codSocio);
  }
}
