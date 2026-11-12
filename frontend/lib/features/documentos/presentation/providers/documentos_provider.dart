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

/// Filtro de visualización para las pestañas de Factura y Cobranza
enum FiltroEstadoFactura { todas, pagadas, impagas, vencidas }

class DocumentosState {
  final bool isLoading;
  final bool isDownloading;
  final String? downloadingDocId;
  final String? errorMessage;
  final ListaDocumentosModel? documentosResponse;
  final int selectedTabIndex; // 0: Facturas, 1: Avisos Cobranza
  final String? currentCodSocio;
  final FiltroEstadoFactura filtroFacturas;
  final FiltroEstadoFactura filtroCobranza;

  const DocumentosState({
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadingDocId,
    this.errorMessage,
    this.documentosResponse,
    this.selectedTabIndex = 0,
    this.currentCodSocio,
    this.filtroFacturas = FiltroEstadoFactura.todas,
    this.filtroCobranza = FiltroEstadoFactura.todas,
  });

  DocumentosState copyWith({
    bool? isLoading,
    bool? isDownloading,
    String? downloadingDocId,
    String? errorMessage,
    ListaDocumentosModel? documentosResponse,
    int? selectedTabIndex,
    String? currentCodSocio,
    FiltroEstadoFactura? filtroFacturas,
    FiltroEstadoFactura? filtroCobranza,
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
      filtroFacturas: filtroFacturas ?? this.filtroFacturas,
      filtroCobranza: filtroCobranza ?? this.filtroCobranza,
    );
  }

  /// Lista unificada de facturas ordenada cronológicamente (más recientes primero)
  List<DocumentoModel> get facturasUnificadas {
    if (isInquilino) return const [];
    final docs = List<DocumentoModel>.from(documentosResponse?.facturas ?? []);
    docs.sort((a, b) {
      final compAnio = b.anio.compareTo(a.anio);
      if (compAnio != 0) return compAnio;
      return b.mes.compareTo(a.mes);
    });
    return docs;
  }

  /// Lista unificada de avisos de cobranza ordenada cronológicamente (más recientes primero)
  List<DocumentoModel> get avisosCobranzaCompletos {
    final docs = List<DocumentoModel>.from(documentosResponse?.avisosCobranza ?? []);
    docs.sort((a, b) {
      final compAnio = b.anio.compareTo(a.anio);
      if (compAnio != 0) return compAnio;
      return b.mes.compareTo(a.mes);
    });
    return docs;
  }

  /// Calcula el estado de un documento evaluando siempre contra la colección completa
  /// de su tipo (sin verse afectado por filtros activos de UI).
  EstadoDocumento estadoDeDocumento(DocumentoModel doc) {
    if (doc.isFactura) {
      return facturasUnificadas.obtenerEstadoDocumento(doc);
    }
    if (doc.isAvisoCobranza) {
      return avisosCobranzaCompletos.obtenerEstadoDocumento(doc);
    }
    return doc.isPagado ? EstadoDocumento.pagada : EstadoDocumento.impaga;
  }

  /// Facturas filtradas según el estado seleccionado (Todas, Pagadas, Impagas, Vencidas)
  List<DocumentoModel> get facturas {
    final list = facturasUnificadas;
    switch (filtroFacturas) {
      case FiltroEstadoFactura.pagadas:
        return list
            .where((f) => list.obtenerEstadoDocumento(f) == EstadoDocumento.pagada)
            .toList();
      case FiltroEstadoFactura.impagas:
        return list
            .where((f) => list.obtenerEstadoDocumento(f) == EstadoDocumento.impaga)
            .toList();
      case FiltroEstadoFactura.vencidas:
        return list
            .where((f) => list.obtenerEstadoDocumento(f) == EstadoDocumento.vencida)
            .toList();
      case FiltroEstadoFactura.todas:
        return list;
    }
  }

  int get totalFacturasPagadasCount => facturasUnificadas
      .where((f) => facturasUnificadas.obtenerEstadoDocumento(f) == EstadoDocumento.pagada)
      .length;

  int get totalFacturasImpagasCount => facturasUnificadas
      .where((f) => facturasUnificadas.obtenerEstadoDocumento(f) == EstadoDocumento.impaga)
      .length;

  int get totalFacturasVencidasCount => facturasUnificadas
      .where((f) => facturasUnificadas.obtenerEstadoDocumento(f) == EstadoDocumento.vencida)
      .length;

  /// Avisos de cobranza filtrados según el estado seleccionado (Todas, Pagadas, Impagas, Vencidas)
  List<DocumentoModel> get avisosCobranza {
    final list = avisosCobranzaCompletos;
    switch (filtroCobranza) {
      case FiltroEstadoFactura.pagadas:
        return list
            .where((a) => list.obtenerEstadoDocumento(a) == EstadoDocumento.pagada)
            .toList();
      case FiltroEstadoFactura.impagas:
        return list
            .where((a) => list.obtenerEstadoDocumento(a) == EstadoDocumento.impaga)
            .toList();
      case FiltroEstadoFactura.vencidas:
        return list
            .where((a) => list.obtenerEstadoDocumento(a) == EstadoDocumento.vencida)
            .toList();
      case FiltroEstadoFactura.todas:
        return list;
    }
  }

  int get totalCobranzaPagadasCount => avisosCobranzaCompletos
      .where((a) => avisosCobranzaCompletos.obtenerEstadoDocumento(a) == EstadoDocumento.pagada)
      .length;

  int get totalCobranzaImpagasCount => avisosCobranzaCompletos
      .where((a) => avisosCobranzaCompletos.obtenerEstadoDocumento(a) == EstadoDocumento.impaga)
      .length;

  int get totalCobranzaVencidasCount => avisosCobranzaCompletos
      .where((a) => avisosCobranzaCompletos.obtenerEstadoDocumento(a) == EstadoDocumento.vencida)
      .length;

  List<DocumentoModel> get todosDocumentos => documentosResponse?.documentos ?? [];

  List<DocumentoModel> get documentosTabActual {
    switch (selectedTabIndex) {
      case 1:
        return avisosCobranza;
      case 0:
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
  final activeCodSocio = ref.watch(
    multicuentaProvider.select((s) => s.activeSuministro?.codSocio.trim()),
  );

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
    state = state.copyWith(selectedTabIndex: index.clamp(0, 1));
  }

  void cambiarFiltroFacturas(FiltroEstadoFactura filtro) {
    state = state.copyWith(filtroFacturas: filtro);
  }

  void cambiarFiltroCobranza(FiltroEstadoFactura filtro) {
    state = state.copyWith(filtroCobranza: filtro);
  }

  /// Carga la lista de documentos y el historial de 12 meses para el socio especificado o actual.
  Future<void> cargarDocumentos({
    String? codSocio,
    bool forceRefresh = false,
  }) async {
    final targetCodSocio = codSocio ?? state.currentCodSocio;

    if (targetCodSocio == null || targetCodSocio.trim().isEmpty) {
      return;
    }

    final cleanCodSocio = targetCodSocio.trim();

    if (!forceRefresh &&
        state.documentosResponse != null &&
        state.currentCodSocio == cleanCodSocio &&
        !state.isLoading) {
      return;
    }

    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      currentCodSocio: cleanCodSocio,
      clearError: true,
    );

    try {
      final response = await repository.obtenerDocumentos(codSocio: cleanCodSocio);

      int newTabIndex = state.selectedTabIndex.clamp(0, 1);
      if (response.isInquilino && newTabIndex != 1) {
        newTabIndex = 1;
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        documentosResponse: response,
        currentCodSocio: cleanCodSocio,
        selectedTabIndex: newTabIndex,
        clearError: true,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      if (!mounted) return;
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
  Future<String?> guardarDocumentoLocal(DocumentoModel doc) async {
    if (!mounted) return null;
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

      if (!mounted) return filePath;
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
      );

      return filePath;
    } on AppException catch (e) {
      if (!mounted) return null;
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: e.message,
      );
      return null;
    } catch (e) {
      if (!mounted) return null;
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

  /// Descarga temporalmente el documento y dispara el diálogo nativo de compartir
  Future<bool> compartirDocumento(DocumentoModel doc) async {
    if (!mounted) return false;
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

      if (!mounted) return false;
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
      if (!mounted) return false;
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isDownloading: false,
        clearDownloading: true,
        errorMessage: 'Error al compartir documento: ${e.toString()}',
      );
      return false;
    }
  }
}
