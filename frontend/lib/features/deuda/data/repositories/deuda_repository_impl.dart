import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/deuda_repository.dart';
import '../datasources/deuda_remote_datasource.dart';
import '../models/deuda_response_model.dart';

final deudaRepositoryProvider = Provider<DeudaRepository>((ref) {
  final remoteDataSource = ref.watch(deudaRemoteDataSourceProvider);
  return DeudaRepositoryImpl(remoteDataSource);
});

class DeudaRepositoryImpl implements DeudaRepository {
  final DeudaRemoteDataSource _remoteDataSource;

  DeudaRepositoryImpl(this._remoteDataSource);

  @override
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) {
    return _remoteDataSource.obtenerDeudaSuministro(
      codSocio: codSocio,
      forzarRefresco: forzarRefresco,
    );
  }
}
