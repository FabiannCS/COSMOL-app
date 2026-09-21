import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';

/// Contenido de la Pestaña 2: Facturas y Avisos PDF (Fase 2).
class DocumentosTabContent extends StatelessWidget {
  const DocumentosTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Facturas y Avisos', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Descarga de facturas con valor legal y avisos de cobranza en PDF.',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  'Repositorio Digital de Facturas',
                  style: AppTextStyles.subtitle1,
                ),
                const SizedBox(height: 4),
                Text(
                  'Generación y descarga de archivos PDF (Fase 2)',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
