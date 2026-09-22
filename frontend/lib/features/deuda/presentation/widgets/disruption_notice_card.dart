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

  @override
  Widget build(BuildContext context) {
    final cantFacturas = deuda?.cantidadFacturasPendientes ?? 2;
    final mensajeCustom = deuda?.mensajeAlerta;
    final fechaVencimiento = deuda?.fechaProximoVencimiento;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.errorRed.withValues(alpha: 0.4),
          width: 1.2,
        ),
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
                if (fechaVencimiento != null && fechaVencimiento.isNotEmpty)
                  Text(
                    'Fecha de vencimiento: $fechaVencimiento',
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
                      'Con 2 o más facturas pendientes se emite orden de corte según normativa de COSMOL R.L. Regularice su pago a tiempo para evitar la suspensión del servicio.',
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
