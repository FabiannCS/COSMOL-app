import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/documento_model.dart';
import '../../data/repositories/documentos_repository_impl.dart';
import '../../domain/repositories/documentos_repository.dart';

class DocumentosState {
  final bool isLoading;
  final bool isDownloading;
  final String? downloadingDocId;
  final String? errorMessage;
  final ListaDocumentosModel? documentosResponse;
  final int selectedTabIndex; // 0: Facturas, 1: Avisos Cobranza, 2: Avisos Corte
  final String? currentCodSocio;

  const DocumentosState({
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadingDocId,
    this.errorMessage,
    this.documentosResponse,
    this.selectedTabIndex = 0,
    this.currentCodSocio,
  });

  DocumentosState copyWith({
    bool? isLoading,
    bool? isDownloading,
    String? downloadingDocId,
    String? errorMessage,
    ListaDocumentosModel? documentosResponse,
    int? selectedTabIndex,
    String? currentCodSocio,
    bool clearError = false,
    bool clearDownloading = false,
  }) {
    return DocumentosState(
      isLoading: isLoading ?? this.isLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadingDocId: clearDownloading ? null : (downloadingDocId ?? this.downloadingDocId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      documentosResponse: documentosResponse ?? this.documentosResponse,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      currentCodSocio: currentCodSocio ?? this.currentCodSocio,
    );
  }

  List<DocumentoModel> get facturas => documentosResponse?.facturas ?? [];
  List<DocumentoModel> get avisosCobranza => documentosResponse?.avisosCobranza ?? [];
  
  /// Regla Oficial de Negocio COSMOL R.L.:
  /// Un aviso de corte únicamente aplica y se notifica cuando el socio tiene 3 o más facturas pendientes (NO cuando debe 1 o 2).
  List<DocumentoModel> get avisosCorte {
    final rawAvisos = documentosResponse?.avisosCorte ?? [];
    if (rawAvisos.isEmpty) return [];

    final facturasPendientesCount = facturas.where((doc) => doc.isPendiente).length;
    final cobranzasPendientesCount = avisosCobranza.where((doc) => doc.isPendiente).length;

    final cantidadFacturasPendientes = facturasPendientesCount > 0
        ? facturasPendientesCount
        : cobranzasPendientesCount;

    // Si el socio debe menos de 3 facturas (1 o 2), se filtra y NO se muestra el aviso de corte.
    if (cantidadFacturasPendientes < 3) {
      return [];
    }

    return rawAvisos;
  }
  List<DocumentoModel> get todosDocumentos => documentosResponse?.documentos ?? [];

  List<DocumentoModel> get documentosTabActual {
    switch (selectedTabIndex) {
      case 0:
        return facturas;
      case 1:
        return avisosCobranza;
      case 2:
        return avisosCorte;
      default:
        return facturas;
    }
  }

  bool get isTitular => documentosResponse?.isTitular ?? true;
  bool get isInquilino => documentosResponse?.isInquilino ?? false;
}

final documentosProvider =
    StateNotifierProvider<DocumentosNotifier, DocumentosState>((ref) {
  final repository = ref.watch(documentosRepositoryProvider);
  final multicuentaState = ref.watch(multicuentaProvider);
  final activeCodSocio =
      multicuentaState.activeSuministro?.codSocio.trim();

  return DocumentosNotifier(
    repository: repository,
    initialCodSocio: activeCodSocio,
  );
});

class DocumentosNotifier extends StateNotifier<DocumentosState> {
  final DocumentosRepository repository;

  DocumentosNotifier({
    required this.repository,
    String? initialCodSocio,
  }) : super(DocumentosState(currentCodSocio: initialCodSocio)) {
    if (initialCodSocio != null && initialCodSocio.trim().isNotEmpty) {
      cargarDocumentos(codSocio: initialCodSocio);
    }
  }

  void cambiarTab(int index) {
    state = state.copyWith(selectedTabIndex: index);
  }

  /// Carga la lista de documentos para el socio especificado o actual.
  Future<void> cargarDocumentos({
    String? codSocio,
    bool forceRefresh = false,
  }) async {
    final targetCodSocio = codSocio ?? state.currentCodSocio;

    if (targetCodSocio == null || targetCodSocio.trim().isEmpty) {
      return;
    }

    final cleanCodSocio = targetCodSocio.trim();

    // Evitar recargas duplicadas si ya está cargado para este socio y no se fuerza
    if (!forceRefresh &&
        state.documentosResponse != null &&
        state.currentCodSocio == cleanCodSocio &&
        !state.isLoading) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      currentCodSocio: cleanCodSocio,
      clearError: true,
    );

    try {
      final response = await repository.obtenerDocumentos(
        codSocio: cleanCodSocio,
      );

      // Si el socio es inquilino (CONSULTA_PAGO) y estaba en pestaña de facturas (0),
      // moverlo automáticamente a la pestaña de Avisos de Cobranza (1)
      int newTabIndex = state.selectedTabIndex;
      if (response.isInquilino && state.selectedTabIndex != 1) {
        newTabIndex = 1;
      }

      state = state.copyWith(
        isLoading: false,
        documentosResponse: response,
        currentCodSocio: cleanCodSocio,
        selectedTabIndex: newTabIndex,
        clearError: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error inesperado al cargar documentos: ${e.toString()}',
      );
    }
  }

  /// Descarga los bytes del PDF para el visor integrado
  Future<Uint8List> obtenerBytesDocumento(String docId) async {
    return await repository.descargarPdfBytes(docId: docId);
  }

  /// Descarga el archivo PDF y lo guarda en el directorio local del dispositivo.
  /// Retorna la ruta completa al archivo guardado o null si ocurre un error.
  Future<String?> guardarDocumentoLocal(DocumentoModel doc) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingDocId: doc.id,
      clearError: true,
    );

    try {
      final bytes = await repository.descargarPdfBytes(docId: doc.id);

      Directory dir;
      if (!kIsWeb && Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final cosmolDir = Directory('${dir.path}/COSMOL_Documentos');
      if (!await cosmolDir.exists()) {
        await cosmolDir.create(recursive: true);
      }

      final fileName = doc.nombreArchivoSugerido;
      final filePath = '${cosmolDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(bytes, flush: true);

      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
      );

      return filePath;
    } on AppException catch (e) {
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: 'No se pudo guardar el archivo: ${e.toString()}',
      );
      return null;
    }
  }

  /// Abre un archivo local guardado previamente con el visor de PDF del sistema
  Future<OpenResult> abrirArchivoExterno(String filePath) async {
    return await OpenFilex.open(filePath);
  }

  /// Descarga temporalmente el documento y dispara el diálogo nativo de compartir (WhatsApp, email, etc.)
  Future<bool> compartirDocumento(DocumentoModel doc) async {
    state = state.copyWith(
      isDownloading: true,
      downloadingDocId: doc.id,
      clearError: true,
    );

    try {
      final bytes = await repository.descargarPdfBytes(docId: doc.id);
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/${doc.nombreArchivoSugerido}';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
      );

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Documento Oficial de COSMOL R.L. - ${doc.tituloLegible} (${doc.periodoFormateado})',
        subject: doc.tituloLegible,
      );

      return result.status == ShareResultStatus.success;
    } on AppException catch (e) {
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: 'Error al compartir documento: ${e.toString()}',
      );
      return false;
    }
  }
}
