import '../../data/models/resumen_deuda_model.dart';

abstract class DeudaRepository {
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  });

  Future<void> invalidarCacheDeuda({
    required String codSocio,
  });
}
