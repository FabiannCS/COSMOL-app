import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/documentos_repository.dart';
import '../datasources/documentos_remote_datasource.dart';
import '../models/documento_model.dart';

final documentosRepositoryProvider = Provider<DocumentosRepository>((ref) {
  final remoteDataSource = ref.watch(documentosRemoteDataSourceProvider);
  return DocumentosRepositoryImpl(remoteDataSource);
});

class DocumentosRepositoryImpl implements DocumentosRepository {
  final DocumentosRemoteDataSource _remoteDataSource;

  DocumentosRepositoryImpl(this._remoteDataSource);

  @override
  Future<ListaDocumentosModel> obtenerDocumentos({
    required String codSocio,
    String? tipo,
  }) {
    return _remoteDataSource.obtenerDocumentos(
      codSocio: codSocio,
      tipo: tipo,
    );
  }

  @override
  Future<Uint8List> descargarPdfBytes({
    required String docId,
  }) {
    return _remoteDataSource.descargarPdfBytes(
      docId: docId,
    );
  }
}
