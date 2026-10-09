import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/documento_model.dart';
import '../../data/models/historial_factura_item_model.dart';
import '../../data/repositories/documentos_repository_impl.dart';
import '../../domain/repositories/documentos_repository.dart';

/// Filtro de visualización para la pestaña de facturas
enum FiltroEstadoFactura { todas, pagadas, pendientes }

class DocumentosState {
  final bool isLoading;
  final bool isDownloading;
  final String? downloadingDocId;
  final String? errorMessage;
  final ListaDocumentosModel? documentosResponse;
  final int selectedTabIndex; // 0: Facturas, 1: Avisos Cobranza, 2: Avisos Corte
  final String? currentCodSocio;
  final FiltroEstadoFactura filtroFacturas;
  final List<HistorialFacturaItemModel> historial12Meses;

  const DocumentosState({
    this.isLoading = false,
    this.isDownloading = false,
    this.downloadingDocId,
    this.errorMessage,
    this.documentosResponse,
    this.selectedTabIndex = 0,
    this.currentCodSocio,
    this.filtroFacturas = FiltroEstadoFactura.todas,
    this.historial12Meses = const [],
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
    List<HistorialFacturaItemModel>? historial12Meses,
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
      historial12Meses: historial12Meses ?? this.historial12Meses,
    );
  }

  /// Lista unificada y enriquecida de facturas de los últimos 12 meses
  List<DocumentoModel> get facturasUnificadas {
    if (isInquilino) return const [];
    final docsDb = documentosResponse?.facturas ?? [];
    final Map<String, DocumentoModel> mapaDocs = {
      for (final d in docsDb) '${d.anio}_${d.mes}': d,
    };

    final List<DocumentoModel> resultado = [];

    // 1. Integrar elementos del historial de 12 meses de COSMOL
    for (final item in historial12Meses) {
      final key = '${item.anio}_${item.mes}';
      if (mapaDocs.containsKey(key)) {
        final docOriginal = mapaDocs.remove(key)!;
        resultado.add(
          docOriginal.copyWith(
            fechaPago: item.fechaPago ?? docOriginal.fechaPago,
            estadoPago: item.isPagado ? 'PAGADO' : docOriginal.estadoPago,
            nroFactura: docOriginal.nroFactura ?? item.nroFactura,
          ),
        );
      } else {
        resultado.add(
          DocumentoModel(
            id: 'hist_${item.anio}_${item.mes}',
            codSocio: item.codigo,
            tipoDocumento: 'FACTURA',
            nroFactura: item.nroFactura,
            periodo: item.periodo,
            anio: item.anio,
            mes: item.mes,
            montoBs: item.monto,
            fechaEmision: DateTime(item.anio, item.mes, 14),
            fechaVencimiento: null,
            estadoPago: item.isPagado ? 'PAGADO' : 'PENDIENTE',
            fechaPago: item.fechaPago,
            permiteDescarga: false,
          ),
        );
      }
    }

    // 2. Agregar cualquier factura de la BD que no haya estado en el historial
    resultado.addAll(mapaDocs.values);

    // 3. Ordenar cronológicamente descendente (más recientes primero)
    resultado.sort((a, b) {
      final compAnio = b.anio.compareTo(a.anio);
      if (compAnio != 0) return compAnio;
      return b.mes.compareTo(a.mes);
    });

    return resultado;
  }

  /// Facturas filtradas según el estado seleccionado (Todas, Pagadas, Pendientes)
  List<DocumentoModel> get facturas {
    final list = facturasUnificadas;
    switch (filtroFacturas) {
      case FiltroEstadoFactura.pagadas:
        return list.where((f) => f.isPagado).toList();
      case FiltroEstadoFactura.pendientes:
        return list.where((f) => f.isPendiente).toList();
      case FiltroEstadoFactura.todas:
        return list;
    }
  }

  int get totalFacturasPagadasCount =>
      facturasUnificadas.where((f) => f.isPagado).length;

  int get totalFacturasPendientesCount =>
      facturasUnificadas.where((f) => f.isPendiente).length;

  List<DocumentoModel> get avisosCobranza => documentosResponse?.avisosCobranza ?? [];
  
  /// Regla Oficial de Negocio COSMOL R.L.:
  /// Un aviso de corte únicamente aplica y se notifica cuando el socio tiene 3 o más facturas pendientes.
  List<DocumentoModel> get avisosCorte {
    final rawAvisos = documentosResponse?.avisosCorte ?? [];
    if (rawAvisos.isEmpty) return [];

    final facturasPendientesCount = facturasUnificadas.where((doc) => doc.isPendiente).length;
    final cobranzasPendientesCount = avisosCobranza.where((doc) => doc.isPendiente).length;

    final cantidadFacturasPendientes = facturasPendientesCount > 0
        ? facturasPendientesCount
        : cobranzasPendientesCount;

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
    state = state.copyWith(selectedTabIndex: index);
  }

  void cambiarFiltroFacturas(FiltroEstadoFactura filtro) {
    state = state.copyWith(filtroFacturas: filtro);
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
      // Consultar en paralelo los documentos organizados y el historial de 12 meses
      final results = await Future.wait([
        repository.obtenerDocumentos(codSocio: cleanCodSocio),
        repository.obtenerHistorial12Meses(codSocio: cleanCodSocio).catchError((_) => <HistorialFacturaItemModel>[]),
      ]);

      final response = results[0] as ListaDocumentosModel;
      final historial12 = results[1] as List<HistorialFacturaItemModel>;

      int newTabIndex = state.selectedTabIndex;
      if (response.isInquilino && state.selectedTabIndex != 1) {
        newTabIndex = 1;
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        documentosResponse: response,
        historial12Meses: historial12,
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
