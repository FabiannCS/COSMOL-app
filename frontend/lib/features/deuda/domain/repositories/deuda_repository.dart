import '../../data/models/deuda_response_model.dart';

abstract class DeudaRepository {
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  });
}
