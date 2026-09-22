import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../providers/consumo_provider.dart';

/// Tarjeta detallada con el desglose de lecturas de medidor, facturación y comparativa del mes seleccionado.
class ConsumoDetailCard extends StatelessWidget {
  final ConsumoState state;

  const ConsumoDetailCard({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final selectedFactura = state.selectedFactura;
    if (selectedFactura == null) return const SizedBox.shrink();

    final promedio = state.promedioConsumo;
    final diferencia = selectedFactura.consumoM3 - promedio;
    final diferenciaAbs = diferencia.abs().toStringAsFixed(1);
    final isBajoPromedio = diferencia <= 0;
    final mayorAhorro = state.mayorAhorroFactura;
    final esElMesDeMayorAhorro = mayorAhorro != null &&
        mayorAhorro.mes == selectedFactura.mes &&
        mayorAhorro.anio == selectedFactura.anio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06003E6B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Encabezado del Mes Seleccionado
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle: ${selectedFactura.mesNombreCompleto} ${selectedFactura.anio}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Cajas de Volumen y Monto
          Row(
            children: [
              // Caja 1: Volumen Consumido
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderSubtle.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOLUMEN CONSUMIDO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFactura.consumoFormateado,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedFactura.litrosMedidos} Litros',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Caja 2: Total Facturado
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderSubtle.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IMPORTE FACTURADO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFactura.montoFormateado,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tarifa: Bs ${selectedFactura.tarifaPorM3.toStringAsFixed(2)}/m³',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Desglose de Lecturas Técnicas del Medidor
          if (selectedFactura.lecturaActual > 0 || selectedFactura.lecturaAnterior > 0 || selectedFactura.fechaLectura != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildReadingItem(
                    label: 'Lectura Anterior',
                    value: '${selectedFactura.lecturaAnterior.toInt()}',
                  ),
                  Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                  _buildReadingItem(
                    label: 'Lectura Actual',
                    value: '${selectedFactura.lecturaActual.toInt()}',
                  ),
                  if (selectedFactura.fechaLectura != null) ...[
                    Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                    _buildReadingItem(
                      label: 'Fecha Toma',
                      value: selectedFactura.fechaLectura!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 4. Tarjeta Explicativa de Comparación con el Promedio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBajoPromedio
                  ? AppColors.successBackground
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBajoPromedio
                    ? AppColors.successGreen.withValues(alpha: 0.25)
                    : const Color(0xFFF97316).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isBajoPromedio
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  size: 18,
                  color: isBajoPromedio
                      ? AppColors.successGreen
                      : const Color(0xFFEA580C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBajoPromedio
                            ? 'Consumo bajo el promedio habitual'
                            : 'Consumo sobre el promedio habitual',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isBajoPromedio
                              ? const Color(0xFF15803D)
                              : const Color(0xFFC2410C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBajoPromedio
                            ? 'En este mes consumió $diferenciaAbs m³ menos que su promedio de ${promedio.toStringAsFixed(1)} m³.'
                            : 'En este mes registró $diferenciaAbs m³ adicionales respecto a su promedio de ${promedio.toStringAsFixed(1)} m³.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: isBajoPromedio
                              ? const Color(0xFF166534)
                              : const Color(0xFF9A3412),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Banner Extra si es el mes de mayor ahorro
          if (esElMesDeMayorAhorro) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [        
                  Expanded(
                    child: Text(
                      '¡Este fue su mes con menor consumo del período analizado!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF047857),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadingItem({required String label, required String value}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
