import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/login_response_model.dart';
import '../../domain/repositories/multicuenta_repository.dart';
import '../datasources/multicuenta_remote_datasource.dart';

final multicuentaRepositoryProvider = Provider<MulticuentaRepository>((ref) {
  final remoteDataSource = ref.watch(multicuentaRemoteDataSourceProvider);
  return MulticuentaRepositoryImpl(remoteDataSource);
});

class MulticuentaRepositoryImpl implements MulticuentaRepository {
  final MulticuentaRemoteDataSource _remoteDataSource;

  MulticuentaRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<SuministroModel>> listarSuministros() {
    return _remoteDataSource.listarSuministros();
  }

  @override
  Future<SuministroModel> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) {
    return _remoteDataSource.vincularSuministro(
      codSocio: codSocio,
      ciOMedidor: ciOMedidor,
      alias: alias,
    );
  }
}
