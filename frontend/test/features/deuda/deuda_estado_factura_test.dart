import 'package:cosmol_app/features/deuda/data/models/pago_model.dart';
import 'package:cosmol_app/features/deuda/data/models/resumen_deuda_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/pagos_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/pagos_provider.dart';
import 'package:cosmol_app/features/deuda/presentation/widgets/balance_card_widget.dart';
import 'package:cosmol_app/features/deuda/presentation/widgets/pago_qr_mock_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePagosRepository implements PagosRepository {
  @override
  Future<CanalesPagoResponseModel> obtenerCanalesPago({required String codSocio}) async {
    return CanalesPagoResponseModel(
      codSocio: codSocio,
      nombreTitular: 'Socio Test',
      totalDeudaBs: 0,
      cantFacturasPendientes: 0,
      canales: const [],
      mensajeAyuda: '',
    );
  }

  @override
  Future<RegistrarIntentoPagoResponseModel> registrarIntentoPago({
    required String codSocio,
    required String canalId,
  }) async {
    return RegistrarIntentoPagoResponseModel(
      exito: true,
      codSocio: codSocio,
      canalId: canalId,
      mensaje: 'OK',
      urlRedireccion: 'https://multipago.com',
    );
  }

  @override
  Future<SimularPagoResponseModel> simularPago({
    required String codSocio,
    required String canalId,
    required double montoBs,
    String? periodos,
  }) async {
    return SimularPagoResponseModel(
      exito: true,
      codSocio: codSocio,
      canalId: canalId,
      nroTransaccion: 'TRX-1',
      montoBs: montoBs,
      fechaPago: '2026-11-10',
      mensaje: 'OK',
      esSimulacion: true,
    );
  }

  @override
  Future<EstadoVerificacionPagoModel> verificarEstadoPago({
    required String codSocio,
  }) async {
    return EstadoVerificacionPagoModel(
      codSocio: codSocio,
      deudaSaldada: false,
      saldoActualBs: 0,
      cantFacturasPendientes: 0,
      mensaje: 'OK',
      ventanaActiva: false,
    );
  }
}

FacturaPendienteModel _crearFacturaDeuda({
  required String nroFacip,
  required String nroFactura,
  required int anio,
  required int mes,
  required String mesLectura,
  double montoBs = 60.0,
  bool estaVencidaBackend = true,
  int diasMora = 30,
}) {
  final mm = mes.toString().padLeft(2, '0');
  return FacturaPendienteModel(
    nroFacip: nroFacip,
    nroFactura: nroFactura,
    codAutorizacion: 'AUTH-$nroFacip',
    periodo: '$mm/$anio',
    mesLectura: mesLectura,
    anio: anio,
    mes: mes,
    montoBs: montoBs,
    estaVencida: estaVencidaBackend,
    diasMora: diasMora,
  );
}

void main() {
  group('Reglas de Negocio - Estados de Facturas en Deuda (3 estados)', () {
    test('Una sola factura no pagada retorna impaga aunque el backend marque estaVencida=true', () {
      final facturas = [
        _crearFacturaDeuda(
          nroFacip: 'F-1',
          nroFactura: '101',
          anio: 2026,
          mes: 8,
          mesLectura: 'Agosto 2026',
          estaVencidaBackend: true,
        ),
      ];

      expect(
        facturas.obtenerEstadoFactura(facturas[0]),
        EstadoFacturaDeuda.impaga,
      );
    });

    test('Dos facturas no pagadas retornan ambas impaga aunque estaVencida=true (<= 2)', () {
      final facturas = [
        _crearFacturaDeuda(
          nroFacip: 'F-1',
          nroFactura: '101',
          anio: 2026,
          mes: 8,
          mesLectura: 'Agosto 2026',
          estaVencidaBackend: true,
        ),
        _crearFacturaDeuda(
          nroFacip: 'F-2',
          nroFactura: '102',
          anio: 2026,
          mes: 9,
          mesLectura: 'Septiembre 2026',
          estaVencidaBackend: true,
        ),
      ];

      expect(facturas.obtenerEstadoFactura(facturas[0]), EstadoFacturaDeuda.impaga);
      expect(facturas.obtenerEstadoFactura(facturas[1]), EstadoFacturaDeuda.impaga);
    });

    test('Con 3 facturas impagas: [vencida, impaga, impaga]', () {
      final facturas = [
        _crearFacturaDeuda(
          nroFacip: 'F-3',
          nroFactura: '103',
          anio: 2026,
          mes: 3,
          mesLectura: 'Marzo 2026',
        ),
        _crearFacturaDeuda(
          nroFacip: 'F-4',
          nroFactura: '104',
          anio: 2026,
          mes: 4,
          mesLectura: 'Abril 2026',
        ),
        _crearFacturaDeuda(
          nroFacip: 'F-5',
          nroFactura: '105',
          anio: 2026,
          mes: 5,
          mesLectura: 'Mayo 2026',
        ),
      ];

      final estados = facturas.map((f) => facturas.obtenerEstadoFactura(f)).toList();

      expect(estados, [
        EstadoFacturaDeuda.vencida, // Marzo
        EstadoFacturaDeuda.impaga,  // Abril
        EstadoFacturaDeuda.impaga,  // Mayo
      ]);
    });

    test('Con 5 facturas impagas: las 2 más recientes impagas y las 3 más antiguas vencidas', () {
      final facturas = [
        _crearFacturaDeuda(nroFacip: 'F-2', nroFactura: '202', anio: 2026, mes: 2, mesLectura: 'Febrero 2026'),
        _crearFacturaDeuda(nroFacip: 'F-3', nroFactura: '203', anio: 2026, mes: 3, mesLectura: 'Marzo 2026'),
        _crearFacturaDeuda(nroFacip: 'F-4', nroFactura: '204', anio: 2026, mes: 4, mesLectura: 'Abril 2026'),
        _crearFacturaDeuda(nroFacip: 'F-5', nroFactura: '205', anio: 2026, mes: 5, mesLectura: 'Mayo 2026'),
        _crearFacturaDeuda(nroFacip: 'F-6', nroFactura: '206', anio: 2026, mes: 6, mesLectura: 'Junio 2026'),
      ];

      final estados = facturas.map((f) => facturas.obtenerEstadoFactura(f)).toList();

      expect(estados, [
        EstadoFacturaDeuda.vencida, // Febrero
        EstadoFacturaDeuda.vencida, // Marzo
        EstadoFacturaDeuda.vencida, // Abril
        EstadoFacturaDeuda.impaga,  // Mayo
        EstadoFacturaDeuda.impaga,  // Junio
      ]);
    });

    test('Lista desordenada cronológicamente sigue dejando solo las 2 más recientes como impaga', () {
      final facturasDesordenadas = [
        _crearFacturaDeuda(nroFacip: 'F-6', nroFactura: '206', anio: 2026, mes: 6, mesLectura: 'Junio 2026'),
        _crearFacturaDeuda(nroFacip: 'F-3', nroFactura: '203', anio: 2026, mes: 3, mesLectura: 'Marzo 2026'),
        _crearFacturaDeuda(nroFacip: 'F-5', nroFactura: '205', anio: 2026, mes: 5, mesLectura: 'Mayo 2026'),
        _crearFacturaDeuda(nroFacip: 'F-4', nroFactura: '204', anio: 2026, mes: 4, mesLectura: 'Abril 2026'),
      ];

      final estados = facturasDesordenadas
          .map((f) => facturasDesordenadas.obtenerEstadoFactura(f))
          .toList();

      expect(estados, [
        EstadoFacturaDeuda.impaga,  // Junio (reciente)
        EstadoFacturaDeuda.vencida, // Marzo (antigua)
        EstadoFacturaDeuda.impaga,  // Mayo (reciente)
        EstadoFacturaDeuda.vencida, // Abril (antigua)
      ]);
    });
  });

  group('Widgets Deuda - BalanceCardWidget y PagoQrMockSheet', () {
    testWidgets('BalanceCardWidget con 2 facturas impagas muestra 2 Impaga y 0 Vencida', (tester) async {
      final deuda = ResumenDeudaModel(
        codSocio: '23807',
        saldoPendienteBs: 140.0,
        cantidadFacturasPendientes: 2,
        estaVencido: true,
        alertaCorte: false,
        facturasPendientes: [
          _crearFacturaDeuda(
            nroFacip: 'F-1',
            nroFactura: '101',
            anio: 2026,
            mes: 8,
            mesLectura: 'Agosto 2026',
            montoBs: 65.0,
            estaVencidaBackend: true,
          ),
          _crearFacturaDeuda(
            nroFacip: 'F-2',
            nroFactura: '102',
            anio: 2026,
            mes: 9,
            mesLectura: 'Septiembre 2026',
            montoBs: 75.0,
            estaVencidaBackend: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BalanceCardWidget(
                  deuda: deuda,
                  onVerRecibo: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Impaga'), findsNWidgets(2));
      expect(find.text('Vencida'), findsNothing);
      expect(find.text('Pendiente'), findsNothing);
    });

    testWidgets('BalanceCardWidget con 5 facturas impagas muestra 3 Vencida y 2 Impaga', (tester) async {
      final deuda = ResumenDeudaModel(
        codSocio: '23807',
        saldoPendienteBs: 300.0,
        cantidadFacturasPendientes: 5,
        estaVencido: true,
        alertaCorte: true,
        facturasPendientes: [
          _crearFacturaDeuda(nroFacip: 'F-2', nroFactura: '202', anio: 2026, mes: 2, mesLectura: 'Febrero 2026'),
          _crearFacturaDeuda(nroFacip: 'F-3', nroFactura: '203', anio: 2026, mes: 3, mesLectura: 'Marzo 2026'),
          _crearFacturaDeuda(nroFacip: 'F-4', nroFactura: '204', anio: 2026, mes: 4, mesLectura: 'Abril 2026'),
          _crearFacturaDeuda(nroFacip: 'F-5', nroFactura: '205', anio: 2026, mes: 5, mesLectura: 'Mayo 2026'),
          _crearFacturaDeuda(nroFacip: 'F-6', nroFactura: '206', anio: 2026, mes: 6, mesLectura: 'Junio 2026'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BalanceCardWidget(
                  deuda: deuda,
                  onVerRecibo: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Vencida'), findsNWidgets(3));
      expect(find.text('Impaga'), findsNWidgets(2));
      expect(find.text('Pendiente'), findsNothing);
    });

    testWidgets('PagoQrMockSheet aplica la regla de 2 impagas y antiguas vencidas en la selección', (tester) async {
      final facturas = [
        _crearFacturaDeuda(nroFacip: 'F-7', nroFactura: '307', anio: 2026, mes: 7, mesLectura: 'Julio 2026'),
        _crearFacturaDeuda(nroFacip: 'F-8', nroFactura: '308', anio: 2026, mes: 8, mesLectura: 'Agosto 2026'),
        _crearFacturaDeuda(nroFacip: 'F-9', nroFactura: '309', anio: 2026, mes: 9, mesLectura: 'Septiembre 2026'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pagosProvider.overrideWith(
              (ref) => PagosNotifier(_FakePagosRepository()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PagoQrMockSheet(
                codSocio: '23807',
                nombreTitular: 'Socio Test',
                montoBs: 180.0,
                cantFacturas: 3,
                facturas: facturas,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Impaga'), findsNWidgets(2));
      expect(find.text('Pendiente'), findsNothing);
    });
  });
}

