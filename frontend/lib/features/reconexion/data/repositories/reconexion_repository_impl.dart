import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/reconexion_repository.dart';
import '../datasources/reconexion_remote_datasource.dart';
import '../models/elegibilidad_reconexion_model.dart';
import '../models/reconexion_tramite_model.dart';
import '../models/solicitud_reconexion_model.dart';

final reconexionRepositoryProvider = Provider<ReconexionRepository>((ref) {
  final dataSource = ref.watch(reconexionRemoteDataSourceProvider);
  return ReconexionRepositoryImpl(dataSource);
});

class ReconexionRepositoryImpl implements ReconexionRepository {
  final ReconexionRemoteDataSource _remoteDataSource;

  ReconexionRepositoryImpl(this._remoteDataSource);

  @override
  Future<ElegibilidadReconexionModel> checkElegibilidad(String codSocio) {
    return _remoteDataSource.checkElegibilidad(codSocio);
  }

  @override
  Future<List<ReconexionTramiteModel>> getHistorial(String codSocio) {
    return _remoteDataSource.getHistorial(codSocio);
  }

  @override
  Future<String> subirFotoEvidencia({
    required Uint8List bytes,
    required String filename,
    required String codSocio,
  }) {
    return _remoteDataSource.subirFotoEvidencia(
      bytes: bytes,
      filename: filename,
      codSocio: codSocio,
    );
  }

  @override
  Future<RespuestaSolicitudReconexionModel> solicitarReconexion(
    SolicitudReconexionPayload payload,
  ) {
    return _remoteDataSource.solicitarReconexion(payload);
  }
}

