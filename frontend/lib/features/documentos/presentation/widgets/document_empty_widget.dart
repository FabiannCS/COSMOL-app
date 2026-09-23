import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';

/// Widget de estado vacío para cada pestaña de documentos.
class DocumentEmptyWidget extends StatelessWidget {
  final int tabIndex;
  final bool isInquilino;
  final VoidCallback? onRefresh;

  const DocumentEmptyWidget({
    super.key,
    required this.tabIndex,
    this.isInquilino = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String description;
    IconData icon;

    if (isInquilino && (tabIndex == 0 || tabIndex == 2)) {
      title = tabIndex == 0
          ? 'Facturas no disponibles'
          : 'Avisos de corte no disponibles';
      description =
          'Este suministro está configurado en Modo Consulta y Pago. Las facturas oficiales y avisos de corte están reservados para el titular verificado.';
      icon = Icons.lock_outline_rounded;
    } else {
      switch (tabIndex) {
        case 0:
          title = 'No hay facturas registradas';
          description =
              'Aún no se han emitido facturas digitales para este suministro.';
          icon = Icons.receipt_long_outlined;
          break;
        case 1:
          title = 'Sin avisos de cobranza pendientes';
          description =
              'No tienes avisos de cobranza emitidos en este momento.';
          icon = Icons.mark_email_read_outlined;
          break;
        case 2:
          title = '¡Excelente! Sin avisos de corte';
          description =
              'Tu cuenta se encuentra al día y no presenta ninguna notificación de corte.';
          icon = Icons.verified_user_outlined;
          break;
        default:
          title = 'No hay documentos';
          description = 'No se encontraron registros de documentos.';
          icon = Icons.folder_open_outlined;
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isInquilino && (tabIndex == 0 || tabIndex == 2))
                    ? const Color(0xFFF3F4F6)
                    : tabIndex == 2
                        ? const Color(0xFFE8F8F5)
                        : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: (isInquilino && (tabIndex == 0 || tabIndex == 2))
                    ? Colors.grey.shade600
                    : tabIndex == 2
                        ? const Color(0xFF00A86B)
                        : AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (onRefresh != null &&
                !(isInquilino && (tabIndex == 0 || tabIndex == 2))) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
