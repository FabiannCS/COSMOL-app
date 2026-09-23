import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../providers/consumo_provider.dart';
import '../widgets/consumo_chart_widget.dart';
import '../widgets/consumo_detail_card.dart';
import '../widgets/consumo_history_table.dart';
import '../widgets/consumo_kpi_card.dart';
import '../widgets/consumo_period_selector.dart';

/// Pantalla principal de Consumo Analítico e Historial de Facturas (Fase 4 / 2).
/// Conectada directamente al backend FastAPI y a los datos reales de COSMOL R.L.
class ConsumoScreen extends ConsumerStatefulWidget {
  final VoidCallback? onVerFacturas;

  const ConsumoScreen({
    super.key,
    this.onVerFacturas,
  });

  @override
  ConsumerState<ConsumoScreen> createState() => _ConsumoScreenState();
}

class _ConsumoScreenState extends ConsumerState<ConsumoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeSuministro = ref.read(multicuentaProvider).activeSuministro;
      final codSocio = activeSuministro?.codSocio.trim() ?? '';
      ref.read(consumoProvider.notifier).cargarHistorial(codSocio: codSocio);
    });
  }

  @override
  Widget build(BuildContext context) {
    final consumoState = ref.watch(consumoProvider);
    final consumoNotifier = ref.read(consumoProvider.notifier);
    final multicuentaState = ref.watch(multicuentaProvider);
    final activeSuministro = multicuentaState.activeSuministro;
    final activeCodSocio = activeSuministro?.codSocio.trim() ?? '';

    // Escuchar cambios de suministro para recargar datos automáticamente
    ref.listen(multicuentaProvider.select((s) => s.activeSuministro), (prev, next) {
      if (next != null && (prev == null || prev.codSocio != next.codSocio)) {
        consumoNotifier.cargarHistorial(codSocio: next.codSocio.trim());
      }
    });

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await consumoNotifier.cargarHistorial(
          codSocio: activeCodSocio,
          forzarRefresco: true,
        );
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Barra de Contexto del Suministro Activo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeSuministro?.alias.isNotEmpty == true
                                ? activeSuministro!.alias
                                : 'Socio $activeCodSocio',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            'Código: $activeCodSocio',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: consumoState.isTitular
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      consumoState.isTitular ? 'Titular' : 'Inquilino',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: consumoState.isTitular
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Estado de Carga Inicial
            if (consumoState.isLoading && consumoState.historial == null) ...[
              Container(
                height: 280,
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Cargando historial de consumo...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
            // 3. Estado de Error
            else if (consumoState.errorMessage != null && consumoState.historial == null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.errorRed, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      consumoState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.errorRed,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        consumoNotifier.cargarHistorial(
                          codSocio: activeCodSocio,
                          forzarRefresco: true,
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar Consulta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // 4. Contenido con Datos Reales
            else ...[
              // Banner Preventivo de Fugas / Consumo Atípico
              if (consumoState.consumoAtipico && consumoState.mensajeAlerta != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alerta Preventiva de Posible Fuga',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              consumoState.mensajeAlerta!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: const Color(0xFFB91C1C),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Selector de Período (6 vs 12 Meses)
              ConsumoPeriodSelector(
                selectedPeriodo: consumoState.periodo,
                onPeriodoChanged: (periodo) {
                  consumoNotifier.cambiarPeriodo(periodo);
                },
              ),
              const SizedBox(height: 14),

              // KPI Card Destacada
              ConsumoKpiCard(
                state: consumoState,
              ),
              const SizedBox(height: 14),

              // Gráfica de Consumo Mensual Interactiva
              ConsumoChartWidget(
                facturas: consumoState.filteredFacturas,
                selectedIndex: consumoState.selectedIndex,
                onMonthSelected: (index) {
                  consumoNotifier.seleccionarMes(index);
                },
              ),
              const SizedBox(height: 14),

              // Tarjeta de Detalle del Mes Seleccionado
              if (consumoState.selectedFactura != null) ...[
                ConsumoDetailCard(
                  state: consumoState,
                ),
                const SizedBox(height: 14),
              ],

              // Tabla Histórica Detallada de Lecturas
              ConsumoHistoryTable(
                facturas: consumoState.filteredFacturas,
                periodo: consumoState.periodo,
                tarifaReferencial: consumoState.tarifaReferencial,
                selectedIndex: consumoState.selectedIndex,
                onSelectMes: (index) {
                  consumoNotifier.seleccionarMes(index);
                },
                onExportarPdf: () {
                  if (widget.onVerFacturas != null) {
                    widget.onVerFacturas!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El historial de facturas está disponible para descarga en la pestaña Documentos.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
