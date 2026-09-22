import '../../data/models/consumo_factura_model.dart';

abstract class ConsumoRepository {
  /// Obtiene el historial completo de facturas, lecturas y analítica de consumo para un socio específico.
  Future<HistorialConsumoModel> obtenerHistorialConsumo({
    required String codSocio,
    bool forzarRefresco = false,
    int meses = 12,
  });

  /// Invalida la memoria caché en Redis del historial de consumo.
  Future<bool> invalidarCacheConsumo({required String codSocio});
}
