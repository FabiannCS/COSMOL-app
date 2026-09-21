import '../../data/models/consumo_factura_model.dart';

abstract class ConsumoRepository {
  /// Obtiene el historial de facturas y consumo para un socio específico
  Future<List<ConsumoFacturaModel>> obtenerHistorialConsumo({
    required String codSocio,
    String? ci,
  });
}
