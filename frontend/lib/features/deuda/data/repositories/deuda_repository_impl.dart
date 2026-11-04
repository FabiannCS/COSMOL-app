import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/repositories/deuda_repository.dart';
import '../datasources/deuda_remote_datasource.dart';
import '../models/resumen_deuda_model.dart';

final deudaRepositoryProvider = Provider<DeudaRepository>((ref) {
  final remoteDataSource = ref.watch(deudaRemoteDataSourceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return DeudaRepositoryImpl(remoteDataSource, storageService);
});

class DeudaRepositoryImpl implements DeudaRepository {
  final DeudaRemoteDataSource _remoteDataSource;
  final StorageService _storageService;

  DeudaRepositoryImpl(this._remoteDataSource, this._storageService);

  @override
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    try {
      final remote = await _remoteDataSource.obtenerDeudaSuministro(
        codSocio: codSocio,
        forzarRefresco: forzarRefresco,
      );
      // Persistir en almacenamiento local para acceso offline
      await _storageService.saveCachedDeuda(codSocio, remote.toJson());
      return remote;
    } catch (e) {
      // Fallback defensivo a caché offline local ante pérdida de conectividad
      final cachedMap = _storageService.getCachedDeuda(codSocio);
      if (cachedMap != null) {
        return ResumenDeudaModel.fromJson({
          ...cachedMap,
          'origen_datos': 'OFFLINE_CACHE',
        });
      }
      rethrow;
    }
  }

  @override
  Future<void> invalidarCacheDeuda({required String codSocio}) {
    return _remoteDataSource.invalidarCacheDeuda(codSocio: codSocio);
  }
}

