import 'dart:typed_data';
import '../../data/models/documento_model.dart';
import '../../data/models/historial_factura_item_model.dart';

abstract class DocumentosRepository {
  /// Obtiene la lista organizada de documentos para un suministro.
  Future<ListaDocumentosModel> obtenerDocumentos({
    required String codSocio,
    String? tipo,
  });

  /// Descarga los bytes del archivo PDF para visualización o almacenamiento.
  Future<Uint8List> descargarPdfBytes({
    required String docId,
  });

  /// Obtiene el historial cronológico de los últimos 12 meses de facturación del socio.
  Future<List<HistorialFacturaItemModel>> obtenerHistorial12Meses({
    required String codSocio,
  });
}
