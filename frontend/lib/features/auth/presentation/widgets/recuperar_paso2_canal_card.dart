import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import 'verified_socio_card.dart';

/// Tarjeta Paso 2: Selección de Canal de Envío (WhatsApp / SMS) y Despacho OTP
class RecuperarPaso2CanalCard extends StatelessWidget {
  final String codSocio;
  final String? nombreTitular;
  final String? telefonoEnmascarado;
  final String canal;
  final bool isLoading;
  final ValueChanged<String> onCanalChanged;
  final VoidCallback onEnviarOtp;
  final VoidCallback onVolverPaso1;

  const RecuperarPaso2CanalCard({
    super.key,
    required this.codSocio,
    this.nombreTitular,
    this.telefonoEnmascarado,
    required this.canal,
    required this.isLoading,
    required this.onCanalChanged,
    required this.onEnviarOtp,
    required this.onVolverPaso1,
  });

  @override
  Widget build(BuildContext context) {
    return CosmolCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VerifiedSocioCard(
            codSocio: codSocio,
            nombreTitular: nombreTitular,
          ),
          const SizedBox(height: 16),

          Text(
            'Canal de Envío de Seguridad',
            style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Por tu seguridad, el código OTP se enviará estrictamente al número celular registrado en tu cuenta:',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),

          // Número enmascarado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_android, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  (telefonoEnmascarado != null && telefonoEnmascarado!.isNotEmpty)
                      ? telefonoEnmascarado!
                      : 'Número celular registrado',
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Selector de canal (WhatsApp vs SMS)
          Text(
            'Elige cómo recibir tu código:',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildCanalOption(
                  icon: Icons.chat,
                  iconColor: const Color(0xFF25D366),
                  title: 'WhatsApp',
                  subtitle: 'Mensaje',
                  isSelected: canal == 'WHATSAPP',
                  onTap: () => onCanalChanged('WHATSAPP'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCanalOption(
                  icon: Icons.sms_outlined,
                  iconColor: AppColors.primary,
                  title: 'SMS',
                  subtitle: 'Mensaje',
                  isSelected: canal == 'SMS',
                  onTap: () => onCanalChanged('SMS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          CosmolButton(
            text: 'Enviar Código',
            isLoading: isLoading,
            onPressed: onEnviarOtp,
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: onVolverPaso1,
            child: const Text('Volver a cambiar Socio o C.I.'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanalOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? iconColor : AppColors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? iconColor : AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? iconColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
