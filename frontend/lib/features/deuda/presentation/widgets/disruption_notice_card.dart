import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../data/models/resumen_deuda_model.dart';

/// Tarjeta de Alerta y Aviso Preventivo de Corte institucional.
class DisruptionNoticeCard extends StatelessWidget {
  final ResumenDeudaModel? deuda;

  const DisruptionNoticeCard({
    super.key,
    this.deuda,
  });

  /// Convierte fechas recibidas (p. ej. `2026-10-31`) al formato legible `dd/MM/yyyy`.
  static String formatearFechaVencimiento(String rawFecha) {
    final trimmed = rawFecha.trim();
    if (trimmed.isEmpty) return '';

    final isoMatch =
        RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T\s].*)?$')
            .firstMatch(trimmed);
    if (isoMatch != null) {
      final anio = isoMatch.group(1)!;
      final mes = isoMatch.group(2)!.padLeft(2, '0');
      final dia = isoMatch.group(3)!.padLeft(2, '0');
      return '$dia/$mes/$anio';
    }

    final dmyMatch =
        RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(trimmed);
    if (dmyMatch != null) {
      final dia = dmyMatch.group(1)!.padLeft(2, '0');
      final mes = dmyMatch.group(2)!.padLeft(2, '0');
      final anio = dmyMatch.group(3)!;
      return '$dia/$mes/$anio';
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      final dia = parsed.day.toString().padLeft(2, '0');
      final mes = parsed.month.toString().padLeft(2, '0');
      return '$dia/$mes/${parsed.year}';
    }

    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final cantFacturas = deuda?.cantidadFacturasPendientes ?? 2;
    final mensajeCustom = deuda?.mensajeAlerta;
    final fechaRaw = deuda?.fechaProximoVencimiento;
    final fechaFormateada =
        fechaRaw != null ? formatearFechaVencimiento(fechaRaw) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.errorRed, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Aviso Preventivo de Corte',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (fechaFormateada.isNotEmpty)
                  Text(
                    'Fecha de vencimiento: $fechaFormateada',
                    style: AppTextStyles.subtitle2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  )
                else
                  Text(
                    'Acumulación de $cantFacturas facturas impagas',
                    style: AppTextStyles.subtitle2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  mensajeCustom ??
                      'Con 3 o más facturas impagas se emite orden de corte según normativa de COSMOL R.L. Regularice su pago a tiempo para evitar la suspensión del servicio.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
