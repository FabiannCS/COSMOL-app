import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../../core/widgets/cosmol_text_field.dart';

/// Formulario Paso 1: Validación de Titularidad (Código de Socio + C.I.)
class RecuperarPaso1IdentificacionCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController socioCodeController;
  final TextEditingController ciController;
  final bool isLoading;
  final VoidCallback onValidar;

  const RecuperarPaso1IdentificacionCard({
    super.key,
    required this.formKey,
    required this.socioCodeController,
    required this.ciController,
    required this.isLoading,
    required this.onValidar,
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
            Text(
              'Recuperar Contraseña',
              style: AppTextStyles.h3.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'Ingresa tu Código de Socio y Carnet de Identidad registrado en COSMOL para validar tu cuenta.',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            CosmolTextField(
              controller: socioCodeController,
              label: 'Código de Socio',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingrese su código de socio';
                if (v.trim().length < 3) return 'Código demasiado corto';
                return null;
              },
            ),
            const SizedBox(height: 16),

            CosmolTextField(
              controller: ciController,
              label: 'Carnet de Identidad',
              keyboardType: TextInputType.text,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingrese su C.I.';
                if (v.trim().length < 4) return 'C.I. no válido';
                return null;
              },
            ),
            const SizedBox(height: 24),

            CosmolButton(
              text: 'Continuar',
              isLoading: isLoading,
              onPressed: onValidar,
            ),
          ],
        ),
      ),
    );
  }
}
