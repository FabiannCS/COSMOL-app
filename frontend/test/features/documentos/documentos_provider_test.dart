import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/documentos/data/models/documento_model.dart';
import 'package:cosmol_app/features/documentos/domain/repositories/documentos_repository.dart';
import 'package:cosmol_app/features/documentos/presentation/providers/documentos_provider.dart';

class MockDocumentosRepository implements DocumentosRepository {
  bool shouldThrow = false;
  ListaDocumentosModel? mockResponse;
  Uint8List? mockPdfBytes;

  @override
  Future<ListaDocumentosModel> obtenerDocumentos({
    required String codSocio,
    String? tipo,
  }) async {
    if (shouldThrow) {
      throw Exception('Error al conectar con el servidor de documentos');
    }

    if (mockResponse != null) {
      return mockResponse!;
    }

    return ListaDocumentosModel(
      codSocio: codSocio,
      rolAcceso: 'TITULAR',
      totalDocumentos: 2,
      facturas: [
        DocumentoModel(
          id: 'doc-factura-1',
          codSocio: codSocio,
          tipoDocumento: 'FACTURA',
          nroFactura: '84920',
          periodo: '08/2026',
          anio: 2026,
          mes: 8,
          montoBs: 85.50,
          fechaEmision: DateTime(2026, 8, 1),
          fechaVencimiento: DateTime(2026, 8, 25),
          estadoPago: 'PAGADO',
        ),
      ],
      avisosCobranza: [
        DocumentoModel(
          id: 'doc-aviso-1',
          codSocio: codSocio,
          tipoDocumento: 'AVISO_COBRANZA',
          nroFacip: 'FAC-100',
          periodo: '09/2026',
          anio: 2026,
          mes: 9,
          montoBs: 92.00,
          fechaEmision: DateTime(2026, 9, 1),
          fechaVencimiento: DateTime(2026, 9, 25),
          estadoPago: 'PENDIENTE',
        ),
      ],
      avisosCorte: const [],
      documentos: const [],
    );
  }

  @override
  Future<Uint8List> descargarPdfBytes({
    required String docId,
  }) async {
    if (shouldThrow) {
      throw Exception('Error de descarga');
    }
    return mockPdfBytes ?? Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]); // %PDF-1.4
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentosNotifier Tests', () {
    late MockDocumentosRepository mockRepository;
    late DocumentosNotifier notifier;

    setUp(() {
      mockRepository = MockDocumentosRepository();
      notifier = DocumentosNotifier(repository: mockRepository);
    });

    test('Estado inicial es limpio', () {
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isDownloading, false);
      expect(notifier.state.documentosResponse, isNull);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.selectedTabIndex, 0);
    });

    test('cambiarTab actualiza selectedTabIndex y limita indices fuera de rango', () {
      notifier.cambiarTab(1);
      expect(notifier.state.selectedTabIndex, 1);

      notifier.cambiarTab(2);
      expect(notifier.state.selectedTabIndex, 1);

      notifier.cambiarTab(0);
      expect(notifier.state.selectedTabIndex, 0);
    });

    test('cargarDocumentos carga datos exitosamente para titular', () async {
      await notifier.cargarDocumentos(codSocio: '23807');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.documentosResponse, isNotNull);
      expect(notifier.state.facturas.length, 1);
      expect(notifier.state.avisosCobranza.length, 1);
      expect(notifier.state.isTitular, isTrue);
      expect(notifier.state.isInquilino, isFalse);
    });

    test('cargarDocumentos mueve a tab de avisos si el rol es inquilino', () async {
      mockRepository.mockResponse = ListaDocumentosModel(
        codSocio: '556',
        rolAcceso: 'CONSULTA_PAGO',
        totalDocumentos: 1,
        facturas: const [],
        avisosCobranza: [
          DocumentoModel(
            id: 'doc-aviso-inq',
            codSocio: '556',
            tipoDocumento: 'AVISO_COBRANZA',
            periodo: '08/2026',
            anio: 2026,
            mes: 8,
            montoBs: 50.0,
            fechaEmision: DateTime(2026, 8, 1),
          ),
        ],
        avisosCorte: const [],
        documentos: const [],
      );

      await notifier.cargarDocumentos(codSocio: '556');

      expect(notifier.state.isInquilino, isTrue);
      expect(notifier.state.selectedTabIndex, 1); // Auto-redirigido a pestaña 1 (Cobranza)
      expect(notifier.state.avisosCobranza.length, 1);
      expect(notifier.state.facturas.isEmpty, isTrue);
    });

    test('obtenerBytesDocumento retorna flujo binario', () async {
      final bytes = await notifier.obtenerBytesDocumento('doc-factura-1');

      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 37); // '%'
      expect(bytes[1], 80); // 'P'
      expect(bytes[2], 68); // 'D'
      expect(bytes[3], 70); // 'F'
    });

    test('cambiarFiltroFacturas filtra correctamente entre todas, pagadas, impagas y vencidas', () async {
      mockRepository.mockResponse = ListaDocumentosModel(
        codSocio: '23807',
        rolAcceso: 'TITULAR',
        totalDocumentos: 6,
        facturas: [
          DocumentoModel(
            id: 'doc-factura-1',
            codSocio: '23807',
            tipoDocumento: 'FACTURA',
            nroFactura: '84920',
            periodo: '04/2026',
            anio: 2026,
            mes: 4,
            montoBs: 85.50,
            fechaEmision: DateTime(2026, 4, 1),
            fechaVencimiento: DateTime(2026, 4, 25),
            estadoPago: 'PAGADO',
            fechaPago: '2026-04-25',
          ),
          DocumentoModel(
            id: 'doc-factura-2',
            codSocio: '23807',
            tipoDocumento: 'FACTURA',
            nroFactura: '84921',
            periodo: '05/2026',
            anio: 2026,
            mes: 5,
            montoBs: 70.00,
            fechaEmision: DateTime(2026, 5, 1),
            fechaVencimiento: DateTime(2026, 5, 25),
            estadoPago: 'PAGADO',
            fechaPago: '2026-05-28',
          ),
          DocumentoModel(
            id: 'doc-factura-3',
            codSocio: '23807',
            tipoDocumento: 'FACTURA',
            nroFactura: '84922',
            periodo: '06/2026',
            anio: 2026,
            mes: 6,
            montoBs: 75.00,
            fechaEmision: DateTime(2026, 6, 1),
            fechaVencimiento: DateTime(2026, 6, 25),
            estadoPago: 'PENDIENTE',
          ),
          DocumentoModel(
            id: 'doc-factura-4',
            codSocio: '23807',
            tipoDocumento: 'FACTURA',
            nroFactura: '84923',
            periodo: '07/2026',
            anio: 2026,
            mes: 7,
            montoBs: 80.00,
            fechaEmision: DateTime(2026, 7, 1),
            fechaVencimiento: DateTime(2026, 7, 25),
            estadoPago: 'PENDIENTE',
          ),
          DocumentoModel(
            id: 'doc-factura-5',
            codSocio: '23807',
            tipoDocumento: 'FACTURA',
            nroFactura: '84924',
            periodo: '08/2026',
            anio: 2026,
            mes: 8,
            montoBs: 85.00,
            fechaEmision: DateTime(2026, 8, 1),
            fechaVencimiento: DateTime(2026, 8, 25),
            estadoPago: 'PENDIENTE',
          ),
          DocumentoModel(
            id: 'doc-factura-6',
            codSocio: '23807',
            tipoDocumento: 'FACTURA',
            nroFactura: '84925',
            periodo: '09/2026',
            anio: 2026,
            mes: 9,
            montoBs: 90.00,
            fechaEmision: DateTime(2026, 9, 1),
            fechaVencimiento: DateTime(2026, 9, 25),
            estadoPago: 'PENDIENTE',
          ),
        ],
        avisosCobranza: const [],
        avisosCorte: const [],
        documentos: const [],
      );

      await notifier.cargarDocumentos(codSocio: '23807');

      // Todas: 2 pagadas, 2 impagas (08 y 09), 2 vencidas (06 y 07)
      expect(notifier.state.facturas.length, 6);
      expect(notifier.state.totalFacturasPagadasCount, 2);
      expect(notifier.state.totalFacturasImpagasCount, 2);
      expect(notifier.state.totalFacturasVencidasCount, 2);

      // Filtrar por Pagadas
      notifier.cambiarFiltroFacturas(FiltroEstadoFactura.pagadas);
      expect(notifier.state.facturas.length, 2);
      expect(notifier.state.facturas.every((f) => f.isPagado), isTrue);

      // Filtrar por Impagas (deben ser únicamente 08/2026 y 09/2026)
      notifier.cambiarFiltroFacturas(FiltroEstadoFactura.impagas);
      expect(notifier.state.facturas.length, 2);
      expect(
        notifier.state.facturas.map((f) => f.periodo).toSet(),
        {'08/2026', '09/2026'},
      );
      expect(
        notifier.state.facturas
            .every((f) => notifier.state.estadoDeDocumento(f) == EstadoDocumento.impaga),
        isTrue,
      );

      // Filtrar por Vencidas (deben ser 06/2026 y 07/2026, conservando estado vencida)
      notifier.cambiarFiltroFacturas(FiltroEstadoFactura.vencidas);
      expect(notifier.state.facturas.length, 2);
      expect(
        notifier.state.facturas.map((f) => f.periodo).toSet(),
        {'06/2026', '07/2026'},
      );
      expect(
        notifier.state.facturas
            .every((f) => notifier.state.estadoDeDocumento(f) == EstadoDocumento.vencida),
        isTrue,
      );
    });

    test('cambiarFiltroCobranza filtra avisos de cobranza e ignora avisosCorte en la vista de documentos', () async {
      mockRepository.mockResponse = ListaDocumentosModel(
        codSocio: '23807',
        rolAcceso: 'TITULAR',
        totalDocumentos: 5,
        facturas: const [],
        avisosCobranza: [
          DocumentoModel(
            id: 'av-1',
            codSocio: '23807',
            tipoDocumento: 'AVISO_COBRANZA',
            periodo: '05/2026',
            anio: 2026,
            mes: 5,
            montoBs: 50.0,
            fechaEmision: DateTime(2026, 5, 1),
            estadoPago: 'PAGADO',
          ),
          DocumentoModel(
            id: 'av-2',
            codSocio: '23807',
            tipoDocumento: 'AVISO_COBRANZA',
            periodo: '06/2026',
            anio: 2026,
            mes: 6,
            montoBs: 60.0,
            fechaEmision: DateTime(2026, 6, 1),
            estadoPago: 'PENDIENTE',
          ),
          DocumentoModel(
            id: 'av-3',
            codSocio: '23807',
            tipoDocumento: 'AVISO_COBRANZA',
            periodo: '07/2026',
            anio: 2026,
            mes: 7,
            montoBs: 70.0,
            fechaEmision: DateTime(2026, 7, 1),
            estadoPago: 'PENDIENTE',
          ),
          DocumentoModel(
            id: 'av-4',
            codSocio: '23807',
            tipoDocumento: 'AVISO_COBRANZA',
            periodo: '08/2026',
            anio: 2026,
            mes: 8,
            montoBs: 80.0,
            fechaEmision: DateTime(2026, 8, 1),
            estadoPago: 'PENDIENTE',
          ),
        ],
        avisosCorte: [
          DocumentoModel(
            id: 'corte-1',
            codSocio: '23807',
            tipoDocumento: 'AVISO_CORTE',
            periodo: '08/2026',
            anio: 2026,
            mes: 8,
            montoBs: 210.0,
            fechaEmision: DateTime(2026, 8, 15),
            estadoPago: 'PENDIENTE',
          ),
        ],
        documentos: const [],
      );

      await notifier.cargarDocumentos(codSocio: '23807');

      expect(notifier.state.totalCobranzaPagadasCount, 1);
      expect(notifier.state.totalCobranzaVencidasCount, 1);
      expect(notifier.state.totalCobranzaImpagasCount, 2);

      // Aun intentando seleccionar tab 2, debe limitarse a Cobranza (tab 1) y nunca exponer avisosCorte
      notifier.cambiarTab(2);
      expect(notifier.state.selectedTabIndex, 1);
      expect(
        notifier.state.documentosTabActual.any((d) => d.isAvisoCorte),
        isFalse,
      );

      notifier.cambiarFiltroCobranza(FiltroEstadoFactura.pagadas);
      expect(notifier.state.avisosCobranza.length, 1);
      expect(notifier.state.avisosCobranza.first.id, 'av-1');

      notifier.cambiarFiltroCobranza(FiltroEstadoFactura.vencidas);
      expect(notifier.state.avisosCobranza.length, 1);
      expect(notifier.state.avisosCobranza.first.id, 'av-2');

      notifier.cambiarFiltroCobranza(FiltroEstadoFactura.impagas);
      expect(notifier.state.avisosCobranza.length, 2);
      expect(
        notifier.state.avisosCobranza.map((a) => a.id).toSet(),
        {'av-3', 'av-4'},
      );
    });
  });
}

