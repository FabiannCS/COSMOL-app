import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/pagos_repository.dart';
import '../datasources/pagos_remote_datasource.dart';
import '../models/pago_model.dart';

final pagosRepositoryProvider = Provider<PagosRepository>((ref) {
  final remoteDataSource = ref.watch(pagosRemoteDataSourceProvider);
  return PagosRepositoryImpl(remoteDataSource);
});

class PagosRepositoryImpl implements PagosRepository {
  final PagosRemoteDataSource _remoteDataSource;

  PagosRepositoryImpl(this._remoteDataSource);

  @override
  Future<CanalesPagoResponseModel> obtenerCanalesPago({
    required String codSocio,
  }) {
    return _remoteDataSource.obtenerCanalesPago(codSocio: codSocio);
  }

  @override
  Future<RegistrarIntentoPagoResponseModel> registrarIntentoPago({
    required String codSocio,
    required String canalId,
  }) {
    return _remoteDataSource.registrarIntentoPago(
      codSocio: codSocio,
      canalId: canalId,
    );
  }

  @override
  Future<EstadoVerificacionPagoModel> verificarEstadoPago({
    required String codSocio,
  }) {
    return _remoteDataSource.verificarEstadoPago(codSocio: codSocio);
  }
}
