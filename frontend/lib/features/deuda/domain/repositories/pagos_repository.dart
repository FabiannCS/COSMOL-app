import '../../data/models/pago_model.dart';

abstract class PagosRepository {
  Future<CanalesPagoResponseModel> obtenerCanalesPago({
    required String codSocio,
  });

  Future<RegistrarIntentoPagoResponseModel> registrarIntentoPago({
    required String codSocio,
    required String canalId,
  });

  Future<EstadoVerificacionPagoModel> verificarEstadoPago({
    required String codSocio,
  });

  Future<SimularPagoResponseModel> simularPago({
    required String codSocio,
    required String canalId,
    required double montoBs,
    String? periodos,
  });
}
