import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';

/// Stepper Indicator para el flujo de Recuperación de Contraseña (COSMOL R.L.)
/// Diseño unificado, responsivo y sin desbordamientos de pantalla.
class RecuperarPasswordStepper extends StatelessWidget {
  final int currentStep;

  const RecuperarPasswordStepper({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final stepTitles = [
      'Identificación',
      'Canal de Seguridad',
      'Código de Verificación',
      'Nueva Contraseña',
    ];

    final currentTitle = (currentStep >= 1 && currentStep <= 4)
        ? stepTitles[currentStep - 1]
        : 'Recuperar Contraseña';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$currentStep',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentTitle,
                        style: AppTextStyles.subtitle1.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Paso $currentStep de 4',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (index) {
              final stepNum = index + 1;
              final isCompleted = stepNum < currentStep;
              final isCurrent = stepNum == currentStep;

              Color barColor = AppColors.borderSubtle;
              if (isCompleted) {
                barColor = AppColors.successGreen;
              } else if (isCurrent) {
                barColor = AppColors.primary;
              }

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 6.0 : 0.0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
