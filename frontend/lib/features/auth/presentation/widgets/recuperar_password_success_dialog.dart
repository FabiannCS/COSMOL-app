import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';

/// Diálogo modal de confirmación exitosa de recuperación de contraseña
class RecuperarPasswordSuccessDialog extends StatelessWidget {
  final VoidCallback onIniciarSesion;

  const RecuperarPasswordSuccessDialog({
    super.key,
    required this.onIniciarSesion,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onIniciarSesion,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecuperarPasswordSuccessDialog(
        onIniciarSesion: onIniciarSesion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: AppColors.successGreen, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '¡Contraseña Actualizada!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu nuevo PIN personal ha sido guardado exitosamente. Ya puedes iniciar sesión en la aplicación.',
            style: AppTextStyles.body1,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Por seguridad, cualquier sesión abierta en otros dispositivos ha sido cerrada.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        CosmolButton(
          text: 'Iniciar Sesión',
          type: CosmolButtonType.primary,
          onPressed: () {
            Navigator.of(context).pop();
            onIniciarSesion();
          },
        ),
      ],
    );
  }
}
