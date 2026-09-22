import 'dart:typed_data';
import '../../data/models/documento_model.dart';

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
}
