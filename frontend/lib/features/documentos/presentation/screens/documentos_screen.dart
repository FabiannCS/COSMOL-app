import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/documento_model.dart';
import '../providers/documentos_provider.dart';
import '../widgets/document_card_widget.dart';
import '../widgets/document_empty_widget.dart';
import '../widgets/document_inquilino_banner.dart';
import 'pdf_viewer_screen.dart';

/// Pantalla principal para el Repositorio Digital de Documentos y Facturas PDF (Fase 3).
class DocumentosScreen extends ConsumerStatefulWidget {
  const DocumentosScreen({super.key});

  @override
  ConsumerState<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends ConsumerState<DocumentosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentosProvider.notifier).cargarDocumentos(forceRefresh: true);
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    ref.read(documentosProvider.notifier).cambiarTab(_tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _abrirVisorPdf(DocumentoModel documento) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(documento: documento),
      ),
    );
  }

  Future<void> _descargarDocumento(DocumentoModel documento) async {
    final notifier = ref.read(documentosProvider.notifier);
    final path = await notifier.guardarDocumentoLocal(documento);

    if (!mounted) return;

    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento guardado:\n$path'),
          backgroundColor: const Color(0xFF00A86B),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Abrir',
            textColor: Colors.white,
            onPressed: () => notifier.abrirArchivoExterno(path),
          ),
        ),
      );
    } else {
      final error =
          ref.read(documentosProvider).errorMessage ?? 'Error al descargar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _compartirDocumento(DocumentoModel documento) async {
    final notifier = ref.read(documentosProvider.notifier);
    await notifier.compartirDocumento(documento);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentosProvider);
    final multicuentaState = ref.watch(multicuentaProvider);
    final activeSuministro = multicuentaState.activeSuministro;

    // Sincronizar índice de tab controller si el estado del provider cambia externamente
    if (_tabController.index != state.selectedTabIndex) {
      _tabController.animateTo(state.selectedTabIndex);
    }

    final facturasCount = state.facturas.length;
    final avisosCobranzaCount = state.avisosCobranza.length;
    final avisosCorteCount = state.avisosCorte.length;

    return RefreshIndicator(
      onRefresh: () => ref
          .read(documentosProvider.notifier)
          .cargarDocumentos(forceRefresh: true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título de sección y subtítulo informativo
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Facturas y Avisos',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Repositorio digital oficial de COSMOL RL.',
                        style: AppTextStyles.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Banner de Inquilino si aplica
            if (state.isInquilino) const DocumentInquilinoBanner(),

            // Error banner si falló la carga
            if (state.errorMessage != null && !state.isLoading) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.error),
                      onPressed: () => ref
                          .read(documentosProvider.notifier)
                          .cargarDocumentos(forceRefresh: true),
                    ),
                  ],
                ),
              ),
            ],

            // Selector de Pestañas (TabBar)
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                padding: const EdgeInsets.all(4),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Facturas'),
                        if (facturasCount > 0) ...[
                          const SizedBox(width: 4),
                          _buildCountBadge(facturasCount, isSelected: _tabController.index == 0),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Cobranza'),
                        if (avisosCobranzaCount > 0) ...[
                          const SizedBox(width: 4),
                          _buildCountBadge(avisosCobranzaCount, isSelected: _tabController.index == 1),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Cortes'),
                        if (avisosCorteCount > 0) ...[
                          const SizedBox(width: 4),
                          _buildCountBadge(
                            avisosCorteCount,
                            isSelected: _tabController.index == 2,
                            isAlert: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Contenido de la lista según la pestaña seleccionada
            if (state.isLoading && state.documentosResponse == null) ...[
              _buildLoadingShimmer(),
            ] else ...[
              _buildDocumentList(state, activeSuministro),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(int count, {bool isSelected = false, bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAlert
            ? (isSelected ? Colors.white : const Color(0xFFEF4444))
            : (isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isAlert
              ? (isSelected ? const Color(0xFFEF4444) : Colors.white)
              : (isSelected ? Colors.white : AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildDocumentList(DocumentosState state, dynamic activeSuministro) {
    final docs = state.documentosTabActual;

    if (docs.isEmpty) {
      return DocumentEmptyWidget(
        tabIndex: state.selectedTabIndex,
        isInquilino: state.isInquilino,
        onRefresh: () => ref
            .read(documentosProvider.notifier)
            .cargarDocumentos(forceRefresh: true),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isDownloading = state.isDownloading && state.downloadingDocId == doc.id;

        return DocumentCardWidget(
          documento: doc,
          isDownloading: isDownloading,
          onVer: () => _abrirVisorPdf(doc),
          onDescargar: () => _descargarDocumento(doc),
          onCompartir: () => _compartirDocumento(doc),
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
