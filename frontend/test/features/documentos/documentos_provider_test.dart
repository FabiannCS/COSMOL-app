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

    test('cambiarTab actualiza selectedTabIndex', () {
      notifier.cambiarTab(1);
      expect(notifier.state.selectedTabIndex, 1);

      notifier.cambiarTab(2);
      expect(notifier.state.selectedTabIndex, 2);
    });

    test('cargarDocumentos carga datos exitosamente para titular', () async {
      await notifier.cargarDocumentos(codSocio: '23807');

      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.documentosResponse, isNotNull);
      expect(notifier.state.facturas.length, 1);
      expect(notifier.state.avisosCobranza.length, 1);
      expect(notifier.state.avisosCorte.isEmpty, isTrue);
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
  });
}
