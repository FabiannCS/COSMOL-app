import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/deuda/data/models/resumen_deuda_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/deuda_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/deuda_provider.dart';

class MockDeudaRepository implements DeudaRepository {
  bool shouldThrow = false;
  ResumenDeudaModel? mockResponse;
  bool invalidarCacheCalled = false;

  @override
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    if (shouldThrow) {
      throw Exception('Error al conectar con la API de COSMOL');
    }
    return mockResponse ??
        ResumenDeudaModel(
          codSocio: codSocio,
          saldoPendienteBs: 164.50,
          cantidadFacturasPendientes: 2,
          estaVencido: true,
          alertaCorte: true,
          facturasPendientes: const [
            FacturaPendienteModel(
              nroFacip: '1160026',
              nroFactura: '7444051',
              codAutorizacion: '465C3D',
              periodo: '08/2026',
              mesLectura: 'Agosto 2026',
              anio: 2026,
              mes: 8,
              montoBs: 78.00,
              estaVencida: true,
            ),
            FacturaPendienteModel(
              nroFacip: '1160027',
              nroFactura: '7444052',
              codAutorizacion: '465C3D',
              periodo: '09/2026',
              mesLectura: 'Septiembre 2026',
              anio: 2026,
              mes: 9,
              montoBs: 86.50,
              estaVencida: false,
            ),
          ],
        );
  }

  @override
  Future<void> invalidarCacheDeuda({required String codSocio}) async {
    invalidarCacheCalled = true;
  }
}

void main() {
  group('DeudaNotifier Tests', () {
    late MockDeudaRepository mockRepository;
    late DeudaNotifier notifier;

    setUp(() {
      mockRepository = MockDeudaRepository();
      notifier = DeudaNotifier(mockRepository);
    });

    test('Estado inicial es limpio y no está cargando', () {
      expect(notifier.state.isLoading, false);
      expect(notifier.state.resumenDeuda, isNull);
      expect(notifier.state.errorMessage, isNull);
    });

    test('cargarDeuda actualiza resumenDeuda correctamente con datos reales', () async {
      await notifier.cargarDeuda('23807');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.resumenDeuda, isNotNull);
      expect(notifier.state.resumenDeuda!.codSocio, '23807');
      expect(notifier.state.saldoTotal, 164.50);
      expect(notifier.state.cantidadFacturas, 2);
      expect(notifier.state.hasDebt, true);
      // Con 2 facturas pendientes la regla de COSMOL indica que NO hay alerta de corte (solo con 3 o más)
      expect(notifier.state.alertaCorte, false);
      expect(notifier.state.facturas.length, 2);
    });

    test('cargarDeuda maneja errores y actualiza errorMessage', () async {
      mockRepository.shouldThrow = true;

      await notifier.cargarDeuda('99999');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNotNull);
      expect(notifier.state.resumenDeuda, isNull);
    });

    test('refrescar solicita recarga forzada de deuda', () async {
      await notifier.cargarDeuda('540');
      expect(notifier.state.resumenDeuda!.codSocio, '540');

      await notifier.refrescar();
      expect(notifier.state.resumenDeuda!.codSocio, '540');
      expect(notifier.state.isLoading, false);
    });

    test('marcarDeudaComoPagadaSimulada salda totalidad a Bs 0.00', () async {
      await notifier.cargarDeuda('23807');
      expect(notifier.state.saldoTotal, 164.50);

      notifier.marcarDeudaComoPagadaSimulada();

      expect(notifier.state.saldoTotal, 0.0);
      expect(notifier.state.cantidadFacturas, 0);
      expect(notifier.state.hasDebt, false);
      expect(notifier.state.facturas, isEmpty);
    });

    test('marcarDeudaComoPagadaSimulada con pago parcial descuenta facturas seleccionadas', () async {
      await notifier.cargarDeuda('23807');
      expect(notifier.state.saldoTotal, 164.50);
      expect(notifier.state.cantidadFacturas, 2);

      // Pagamos solo la factura '1160026' de 78.00 Bs
      notifier.marcarDeudaComoPagadaSimulada(
        facturasPagadasNroFacip: ['1160026'],
        montoPagado: 78.00,
      );

      expect(notifier.state.saldoTotal, 86.50);
      expect(notifier.state.cantidadFacturas, 1);
      expect(notifier.state.facturas.first.nroFacip, '1160027');
      expect(notifier.state.facturas.first.estaVencida, false);
    });
  });
}
