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
  Future<List<ConsumoFacturaModel>> obtenerHistorialConsumo({
    required String codSocio,
    String? ci,
  }) {
    return remoteDataSource.obtenerHistorialFacturas(
      codSocio: codSocio,
      ci: ci,
    );
  }
}
