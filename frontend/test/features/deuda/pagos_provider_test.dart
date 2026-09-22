import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/deuda/data/models/pago_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/pagos_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/pagos_provider.dart';

class MockPagosRepository implements PagosRepository {
  bool shouldThrow = false;
  CanalesPagoResponseModel? mockCanales;
  RegistrarIntentoPagoResponseModel? mockIntento;

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
      expect(notifier.state.canalesResponse, isNull);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.canales, isEmpty);
    });

    test('cargarCanales obtiene y actualiza canales exitosamente', () async {
      await notifier.cargarCanales('540');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.canalesResponse, isNotNull);
      expect(notifier.state.canales.length, 1);
      expect(notifier.state.canales.first.id, 'multipago');
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
  });
}
