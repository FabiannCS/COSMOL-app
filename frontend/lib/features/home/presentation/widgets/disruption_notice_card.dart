import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';

/// Tarjeta de Alerta y Aviso Preventivo de Corte emitida por COSMOL.
class DisruptionNoticeCard extends StatelessWidget {
  final String? fechaLimite;
  final String? mensajeAlerta;

  const DisruptionNoticeCard({
    super.key,
    this.fechaLimite,
    this.mensajeAlerta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.errorRed, size: 20),
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
                if (fechaLimite != null && fechaLimite!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Límite para evitar corte: $fechaLimite',
                    style: AppTextStyles.subtitle2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  mensajeAlerta != null && mensajeAlerta!.isNotEmpty
                      ? mensajeAlerta!
                      : 'Adeuda facturas de servicio con riesgo de orden de corte según normativa cooperativa. Regularice a tiempo para evitar la suspensión de su suministro.',
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
