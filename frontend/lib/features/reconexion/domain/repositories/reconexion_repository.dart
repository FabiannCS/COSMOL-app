import 'dart:typed_data';
import '../../data/models/elegibilidad_reconexion_model.dart';
import '../../data/models/reconexion_tramite_model.dart';
import '../../data/models/solicitud_reconexion_model.dart';

abstract class ReconexionRepository {
  Future<ElegibilidadReconexionModel> checkElegibilidad(String codSocio);
  Future<List<ReconexionTramiteModel>> getHistorial(String codSocio);
  Future<String> subirFotoEvidencia({
    required Uint8List bytes,
    required String filename,
    required String codSocio,
  });
  Future<RespuestaSolicitudReconexionModel> solicitarReconexion(
    SolicitudReconexionPayload payload,
  );
}

