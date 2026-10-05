import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../../core/widgets/cosmol_text_field.dart';

/// Formulario Paso 4: Creación de Nueva Contraseña / PIN Personal
class RecuperarPaso4PinCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController pinController;
  final TextEditingController confirmPinController;
  final bool isLoading;
  final VoidCallback onGuardarPin;

  const RecuperarPaso4PinCard({
    super.key,
    required this.formKey,
    required this.pinController,
    required this.confirmPinController,
    required this.isLoading,
    required this.onGuardarPin,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: CosmolCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.password,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva Contraseña / PIN',
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                      ),
                      Text(
                        'Paso final: Establece tu nueva credencial',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Crea una contraseña o PIN seguro de al menos 4 caracteres para iniciar sesión en tu cuenta.',
              style:
                  AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            CosmolTextField(
              controller: pinController,
              label: 'Nuevo PIN o Contraseña',
              hint: 'Mínimo 4 caracteres',
              isPassword: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ingrese su nuevo PIN';
                }
                if (v.trim().length < 4) return 'Mínimo 4 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            CosmolTextField(
              controller: confirmPinController,
              label: 'Confirmar Nuevo PIN',
              hint: 'Repita el mismo PIN',
              isPassword: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Confirme su nuevo PIN';
                }
                if (v.trim() != pinController.text.trim()) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            CosmolButton(
              text: 'Guardar Nueva Contraseña',
              isLoading: isLoading,
              onPressed: onGuardarPin,
            ),
          ],
        ),
      ),
    );
  }
}
