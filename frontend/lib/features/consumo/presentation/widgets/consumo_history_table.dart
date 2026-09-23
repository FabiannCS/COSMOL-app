import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../data/models/consumo_factura_model.dart';
import '../providers/consumo_provider.dart';

/// Tabla detallada con el historial de lecturas, volúmenes, montos y estados de cobro.
class ConsumoHistoryTable extends StatelessWidget {
  final List<ConsumoPeriodoModel> facturas;
  final PeriodoConsumo periodo;
  final double tarifaReferencial;
  final int selectedIndex;
  final ValueChanged<int> onSelectMes;
  final VoidCallback onExportarPdf;

  const ConsumoHistoryTable({
    super.key,
    required this.facturas,
    required this.periodo,
    required this.tarifaReferencial,
    this.selectedIndex = 0,
    required this.onSelectMes,
    required this.onExportarPdf,
  });

  @override
  Widget build(BuildContext context) {
    final periodoLabel = periodo == PeriodoConsumo.seisMeses
        ? 'Últimos 6 Meses'
        : 'Últimos 12 Meses';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08003E6B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Historial de Lecturas',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                Text(
                  periodoLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Encabezado de columnas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'MES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'VOLUMEN',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'MONTO',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ESTADO',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filas de datos
          if (facturas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No se encontraron registros de consumo.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: facturas.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final item = facturas[index];
                final isSelected = index == selectedIndex;

                return Material(
                  color: isSelected
                      ? const Color(0xFFEFF6FF)
                      : (index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
                  child: InkWell(
                    onTap: () => onSelectMes(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: isSelected
                            ? const Border(
                                left: BorderSide(
                                  color: AppColors.primary,
                                  width: 3.5,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Mes
                          Expanded(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.mesAnioCorto,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                                ),
                              ),
                            ),
                          ),

                          // Volumen m³
                          Expanded(
                            flex: 2,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                item.consumoFormateado,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.secondary,
                                ),
                              ),
                            ),
                          ),

                          // Monto Bs
                          Expanded(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                item.montoFormateado,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ),

                          // Estado (Pagado / Pendiente) - Overflow-Proof con FittedBox
                          Expanded(
                            flex: 3,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _buildStatusChip(item.isPagado),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // Footer con Tarifa y Exportar PDF
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tarifa: Bs ${tarifaReferencial.toStringAsFixed(2)} / m³',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onExportarPdf,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ver Facturas PDF',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isPagado) {
    if (isPagado) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pagado',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.successGreen,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 3),
            Text(
              'Pendiente',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.errorRed,
              ),
            ),
          ],
        ),
      );
    }
  }
}
