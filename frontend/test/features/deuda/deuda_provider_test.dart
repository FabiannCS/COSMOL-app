import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/deuda/data/models/deuda_response_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/deuda_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/deuda_provider.dart';

class FakeDeudaRepository implements DeudaRepository {
  final ResumenDeudaModel mockResult;
  final bool shouldThrow;

  FakeDeudaRepository({
    required this.mockResult,
    this.shouldThrow = false,
  });

  @override
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    if (shouldThrow) {
      throw Exception('Fallo de red simulado');
    }
    return mockResult;
  }
}

void main() {
  group('DeudaNotifier Tests', () {
    const fakeDeuda = ResumenDeudaModel(
      codSocio: '540',
      saldoPendienteBs: 132.34,
      cantidadFacturasPendientes: 2,
      estaVencido: true,
      alertaCorte: true,
      facturasPendientes: [
        FacturaPendienteModel(
          nroFacip: '1160026',
          nroFactura: '7444051',
          codAutorizacion: 'AUTH1',
          periodo: '07/2026',
          mesLectura: 'Julio 2026',
          anio: 2026,
          mes: 7,
          montoBs: 66.17,
          estaVencida: true,
          diasMora: 15,
        ),
      ],
    );

    test('cargarDeuda actualiza exitosamente el estado con datos reales', () async {
      final repo = FakeDeudaRepository(mockResult: fakeDeuda);
      final notifier = DeudaNotifier(repository: repo);

      await notifier.cargarDeuda(codSocio: '540');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, null);
      expect(notifier.state.deuda, isNotNull);
      expect(notifier.state.deuda!.saldoPendienteBs, 132.34);
      expect(notifier.state.deuda!.cantidadFacturasPendientes, 2);
      expect(notifier.state.deuda!.alertaCorte, true);
      expect(notifier.state.deuda!.hasDebt, true);
    });

    test('cargarDeuda maneja errores y actualiza errorMessage', () async {
      final repo = FakeDeudaRepository(mockResult: fakeDeuda, shouldThrow: true);
      final notifier = DeudaNotifier(repository: repo);

      await notifier.cargarDeuda(codSocio: '540');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.deuda, null);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });
}
