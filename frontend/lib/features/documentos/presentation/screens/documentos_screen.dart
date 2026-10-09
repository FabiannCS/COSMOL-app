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
      ref.read(documentosProvider.notifier).cargarDocumentos(forceRefresh: false);
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
                      const SizedBox(height: 2),
                      Text(
                        'Historial de comprobantes y avisos de cobranza',
                        style: AppTextStyles.caption.copyWith(
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
                        const Text('Factura'),
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
                        const Text('Corte'),
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
            const SizedBox(height: 14),

            // Selector de filtro de facturas (Todas, Pagadas, Pendientes)
            if (_tabController.index == 0) ...[
              _buildFiltroFacturas(state),
              const SizedBox(height: 12),
            ],

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

  Widget _buildFiltroFacturas(DocumentosState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todas (${state.facturasUnificadas.length})',
            isSelected: state.filtroFacturas == FiltroEstadoFactura.todas,
            onSelected: () => ref
                .read(documentosProvider.notifier)
                .cambiarFiltroFacturas(FiltroEstadoFactura.todas),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Pagadas (${state.totalFacturasPagadasCount})',
            isSelected: state.filtroFacturas == FiltroEstadoFactura.pagadas,
            selectedColor: AppColors.primary,
            onSelected: () => ref
                .read(documentosProvider.notifier)
                .cambiarFiltroFacturas(FiltroEstadoFactura.pagadas),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Pendientes (${state.totalFacturasPendientesCount})',
            isSelected: state.filtroFacturas == FiltroEstadoFactura.pendientes,
            selectedColor: AppColors.primary,
            onSelected: () => ref
                .read(documentosProvider.notifier)
                .cambiarFiltroFacturas(FiltroEstadoFactura.pendientes),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    Color? selectedColor,
    required VoidCallback onSelected,
  }) {
    final color = selectedColor ?? AppColors.primary;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
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
        5,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
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
