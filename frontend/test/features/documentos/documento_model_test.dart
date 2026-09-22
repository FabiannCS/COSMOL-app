import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/documentos/data/models/documento_model.dart';

void main() {
  group('DocumentoModel Test', () {
    final mockDocumentoJson = {
      'id': 'a1b2c3d4-e5f6-7890-1234-56789abcdef0',
      'cod_socio': '23807',
      'tipo_documento': 'FACTURA',
      'nro_factura': '84920',
      'nro_facip': 'FAC-12345',
      'cod_autorizacion': 'SIAT-998877665544',
      'periodo': '08/2026',
      'anio': 2026,
      'mes': 8,
      'monto_bs': 85.50,
      'fecha_emision': '2026-08-01',
      'fecha_vencimiento': '2026-08-25',
      'estado_pago': 'PAGADO',
      's3_key': 'facturas/23807/2026_08_84920.pdf',
      'permite_descarga': true,
      'url_descarga': '/api/v1/documentos/a1b2c3d4-e5f6-7890-1234-56789abcdef0/descargar',
    };

    test('debe deserializar un DocumentoModel correctamente desde JSON', () {
      final doc = DocumentoModel.fromJson(mockDocumentoJson);

      expect(doc.id, 'a1b2c3d4-e5f6-7890-1234-56789abcdef0');
      expect(doc.codSocio, '23807');
      expect(doc.tipoDocumento, 'FACTURA');
      expect(doc.nroFactura, '84920');
      expect(doc.isFactura, isTrue);
      expect(doc.isAvisoCobranza, isFalse);
      expect(doc.isAvisoCorte, isFalse);
      expect(doc.isPagado, isTrue);
      expect(doc.isPendiente, isFalse);
      expect(doc.montoBs, 85.50);
      expect(doc.tituloLegible, 'Factura N° 84920');
      expect(doc.periodoFormateado, 'Agosto 2026');
      expect(doc.nombreArchivoSugerido, 'COSMOL_Factura_84920_Socio23807.pdf');
    });

    test('debe serializar y deserializar ListaDocumentosModel respetando los roles', () {
      final mockListaJson = {
        'cod_socio': '23807',
        'rol_acceso': 'TITULAR',
        'total_documentos': 3,
        'facturas': [mockDocumentoJson],
        'avisos_cobranza': [
          {
            ...mockDocumentoJson,
            'id': 'b2c3d4e5-f6a7-8901-2345-6789abcdef01',
            'tipo_documento': 'AVISO_COBRANZA',
            'nro_facip': '98765',
            'estado_pago': 'PENDIENTE',
          }
        ],
        'avisos_corte': [],
        'documentos': [mockDocumentoJson],
      };

      final lista = ListaDocumentosModel.fromJson(mockListaJson);

      expect(lista.codSocio, '23807');
      expect(lista.isTitular, isTrue);
      expect(lista.isInquilino, isFalse);
      expect(lista.totalDocumentos, 3);
      expect(lista.facturas.length, 1);
      expect(lista.avisosCobranza.length, 1);
      expect(lista.avisosCorte.isEmpty, isTrue);
      expect(lista.avisosCobranza.first.isAvisoCobranza, isTrue);
      expect(lista.avisosCobranza.first.isPendiente, isTrue);
    });

    test('debe identificar rol CONSULTA_PAGO para inquilinos', () {
      final mockInquilinoJson = {
        'cod_socio': '556',
        'rol_acceso': 'CONSULTA_PAGO',
        'total_documentos': 1,
        'facturas': [],
        'avisos_cobranza': [mockDocumentoJson],
        'avisos_corte': [],
        'documentos': [mockDocumentoJson],
      };

      final lista = ListaDocumentosModel.fromJson(mockInquilinoJson);

      expect(lista.isTitular, isFalse);
      expect(lista.isInquilino, isTrue);
      expect(lista.facturas.isEmpty, isTrue);
      expect(lista.avisosCobranza.length, 1);
    });
  });
}
