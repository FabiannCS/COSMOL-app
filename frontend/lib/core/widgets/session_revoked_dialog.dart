import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_text_styles.dart';
import 'cosmol_button.dart';

/// Alerta modal de seguridad cuando se detecta un inicio de sesión en un nuevo equipo.
class SessionRevokedDialog extends StatelessWidget {
  final VoidCallback onAccept;

  const SessionRevokedDialog({
    super.key,
    required this.onAccept,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAccept,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SessionRevokedDialog(onAccept: onAccept),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.warningBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_erase_rounded,
                  color: AppColors.warningOrange,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sesión Revocada',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.darkNavy,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Se ha iniciado sesión en otro dispositivo con su Código de Socio. Su sesión activa en este equipo ha sido cerrada por motivos de privacidad y seguridad.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body2,
              ),
              const SizedBox(height: 24),
              CosmolButton(
                text: 'Volver a Iniciar Sesión',
                type: CosmolButtonType.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  onAccept();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
