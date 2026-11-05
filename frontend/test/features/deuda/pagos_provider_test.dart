import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/deuda/data/models/pago_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/pagos_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/pagos_provider.dart';

class MockPagosRepository implements PagosRepository {
  bool shouldThrow = false;
  CanalesPagoResponseModel? mockCanales;
  RegistrarIntentoPagoResponseModel? mockIntento;
  SimularPagoResponseModel? mockSimular;

  @override
  Future<CanalesPagoResponseModel> obtenerCanalesPago({
    required String codSocio,
  }) async {
    if (shouldThrow) {
      throw Exception('Error al conectar con el servidor de pagos');
    }
    return mockCanales ??
        CanalesPagoResponseModel(
          codSocio: codSocio,
          nombreTitular: 'Socio de Prueba',
          totalDeudaBs: 150.0,
          cantFacturasPendientes: 1,
          canales: const [
            CanalPagoModel(
              id: 'multipago',
              nombre: 'Multipago Bolivia',
              descripcion: 'Pago con Simple QR',
              urlRedireccion: 'https://multipago.com/service/cosmol_payment/first',
            ),
          ],
          mensajeAyuda: 'Selecciona una pasarela',
        );
  }

  @override
  Future<RegistrarIntentoPagoResponseModel> registrarIntentoPago({
    required String codSocio,
    required String canalId,
  }) async {
    if (shouldThrow) {
      throw Exception('Error al registrar intento');
    }
    return mockIntento ??
        RegistrarIntentoPagoResponseModel(
          exito: true,
          codSocio: codSocio,
          canalId: canalId,
          mensaje: 'Intención registrada',
          urlRedireccion: 'https://multipago.com/service/cosmol_payment/first',
        );
  }

  @override
  Future<EstadoVerificacionPagoModel> verificarEstadoPago({
    required String codSocio,
  }) async {
    return EstadoVerificacionPagoModel(
      codSocio: codSocio,
      deudaSaldada: false,
      saldoActualBs: 150.0,
      cantFacturasPendientes: 1,
      mensaje: 'Pendiente',
      ventanaActiva: true,
    );
  }

  @override
  Future<SimularPagoResponseModel> simularPago({
    required String codSocio,
    required String canalId,
    required double montoBs,
    String? periodos,
  }) async {
    if (shouldThrow) {
      throw Exception('Error al simular pago');
    }
    return mockSimular ??
        SimularPagoResponseModel(
          exito: true,
          codSocio: codSocio,
          canalId: canalId,
          nroTransaccion: 'TRX-MOCK-TEST-1234',
          montoBs: montoBs,
          fechaPago: '05/11/2026 12:00:00',
          mensaje: 'Simulación exitosa',
          esSimulacion: true,
        );
  }
}

void main() {
  group('PagosNotifier Tests', () {
    late MockPagosRepository repository;
    late PagosNotifier notifier;

    setUp(() {
      repository = MockPagosRepository();
      notifier = PagosNotifier(repository);
    });

    test('Estado inicial es limpio y no está cargando', () {
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isRegistering, false);
      expect(notifier.state.isSimulating, false);
      expect(notifier.state.canalesResponse, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('cargarCanales obtiene y actualiza canales exitosamente', () async {
      await notifier.cargarCanales('540');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.canalesResponse, isNotNull);
      expect(notifier.state.canales.length, 1);
      expect(notifier.state.canales.first.id, 'multipago');
      expect(notifier.state.errorMessage, isNull);
    });

    test('cargarCanales maneja error y actualiza errorMessage', () async {
      repository.shouldThrow = true;

      await notifier.cargarCanales('540');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.canalesResponse, isNull);
      expect(notifier.state.errorMessage, isNotNull);
    });

    test('registrarIntentoYObtenerUrl registra intento y retorna url de redirección', () async {
      final url = await notifier.registrarIntentoYObtenerUrl(
        codSocio: '540',
        canalId: 'multipago',
      );

      expect(url, 'https://multipago.com/service/cosmol_payment/first');
      expect(notifier.state.isRegistering, false);
      expect(notifier.state.errorMessage, isNull);
    });

    test('simularPago ejecuta simulación exitosa y retorna comprobante mock', () async {
      final comprobante = await notifier.simularPago(
        codSocio: '540',
        canalId: 'qr_simple',
        montoBs: 150.0,
      );

      expect(comprobante, isNotNull);
      expect(comprobante!.exito, true);
      expect(comprobante.nroTransaccion, 'TRX-MOCK-TEST-1234');
      expect(comprobante.montoBs, 150.0);
      expect(comprobante.esSimulacion, true);
      expect(notifier.state.isSimulating, false);
      expect(notifier.state.ultimoPagoSimulado, isNotNull);
    });

    test('simularPago maneja error y actualiza errorMessage', () async {
      repository.shouldThrow = true;

      final comprobante = await notifier.simularPago(
        codSocio: '540',
        canalId: 'qr_simple',
        montoBs: 150.0,
      );

      expect(comprobante, isNull);
      expect(notifier.state.isSimulating, false);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });
}
