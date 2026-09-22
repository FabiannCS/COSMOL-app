import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../consumo/presentation/providers/consumo_provider.dart';
import '../../../consumo/presentation/widgets/consumo_chart_widget.dart';
import '../../../consumo/presentation/widgets/consumo_detail_card.dart';
import '../../../consumo/presentation/widgets/consumo_history_table.dart';
import '../../../consumo/presentation/widgets/consumo_kpi_card.dart';
import '../../../consumo/presentation/widgets/consumo_period_selector.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';

/// Contenido de la Pestaña 1: Consumo Analítico (Fase 2).
class ConsumoTabContent extends ConsumerStatefulWidget {
  const ConsumoTabContent({super.key});

  @override
  ConsumerState<ConsumoTabContent> createState() => _ConsumoTabContentState();
}

class _ConsumoTabContentState extends ConsumerState<ConsumoTabContent> {
  @override
  Widget build(BuildContext context) {
    final consumoState = ref.watch(consumoProvider);
    final consumoNotifier = ref.read(consumoProvider.notifier);
    final multicuentaState = ref.watch(multicuentaProvider);
    final activeSuministro = multicuentaState.activeSuministro;

    // Escuchar cambios de suministro para recargar datos
    ref.listen(multicuentaProvider.select((s) => s.activeSuministro), (prev, next) {
      if (next != null && (prev == null || prev.codSocio != next.codSocio)) {
        consumoNotifier.cargarHistorial(codSocio: next.codSocio);
      }
    });

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        final codSocio = activeSuministro?.codSocio.trim();
        if (codSocio != null && codSocio.isNotEmpty) {
          await consumoNotifier.cargarHistorial(codSocio: codSocio);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-header & Quick Context
            Text(
              'Historial de Consumo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),

            if (consumoState.isLoading && consumoState.facturas.isEmpty) ...[
              const SizedBox(height: 60),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Cargando historial de lecturas...',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ] else if (consumoState.errorMessage != null && consumoState.facturas.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44, color: AppColors.errorRed),
                    const SizedBox(height: 12),
                    Text(
                      'Error al cargar el consumo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.errorRed,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      consumoState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        final codSocio = activeSuministro?.codSocio.trim() ?? '23807';
                        consumoNotifier.cargarHistorial(codSocio: codSocio);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 1. Tarjeta Hero de Métrica KPI
              ConsumoKpiCard(state: consumoState),
              const SizedBox(height: 14),

              // 2. Selector de Período (6m vs 12m)
              ConsumoPeriodSelector(
                selectedPeriodo: consumoState.periodo,
                onPeriodoChanged: (periodo) {
                  consumoNotifier.cambiarPeriodo(periodo);
                },
              ),
              const SizedBox(height: 14),

              // 3. Gráfico Interactivo de Evolución de Consumo
              ConsumoChartWidget(
                facturas: consumoState.filteredFacturas,
                selectedIndex: consumoState.selectedIndex ?? 0,
                onMonthSelected: (index) {
                  consumoNotifier.seleccionarMes(index);
                },
              ),
              const SizedBox(height: 10),

              // 4. Detalle Comparativo del Mes Seleccionado
              ConsumoDetailCard(state: consumoState),
              const SizedBox(height: 14),

              // 5. Tabla Detallada de Lecturas Históricas
              ConsumoHistoryTable(
                facturas: consumoState.filteredFacturas,
                periodo: consumoState.periodo,
                tarifaReferencial: consumoState.tarifaReferencial,
                onExportarPdf: () => _handleExportarPdf(context, consumoState),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  void _handleExportarPdf(BuildContext context, ConsumoState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Generando reporte PDF para el Socio ${state.currentCodSocio ?? "23807"}...',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
