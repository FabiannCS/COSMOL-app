import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';

/// Tarjeta Paso 3: Ingreso y Validación de Código OTP de 6 Dígitos
class RecuperarPaso3OtpCard extends StatelessWidget {
  final TextEditingController otpController;
  final String canal;
  final String? telefonoEnmascarado;
  final bool canResend;
  final int secondsRemaining;
  final bool isLoading;
  final VoidCallback onVerificarOtp;
  final VoidCallback onReenviarOtp;
  final VoidCallback onVolverPaso2;

  const RecuperarPaso3OtpCard({
    super.key,
    required this.otpController,
    required this.canal,
    this.telefonoEnmascarado,
    required this.canResend,
    required this.secondsRemaining,
    required this.isLoading,
    required this.onVerificarOtp,
    required this.onReenviarOtp,
    required this.onVolverPaso2,
  });

  @override
  Widget build(BuildContext context) {
    return CosmolCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.successGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código Enviado',
                      style: AppTextStyles.h3.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Vía ${canal == "WHATSAPP" ? "WhatsApp" : "SMS"}${(telefonoEnmascarado != null && telefonoEnmascarado!.isNotEmpty) ? " al $telefonoEnmascarado" : " a su número registrado"}',
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
            'Ingresa el código numérico de 6 dígitos que enviamos a tu celular.',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Campo de 6 dígitos
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
              color: AppColors.textPrimary,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.grey.shade300,
                letterSpacing: 10,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (val) {
              if (val.length == 6) {
                onVerificarOtp();
              }
            },
          ),
          const SizedBox(height: 16),

          // Reenvío de código y timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!canResend) ...[
                const Icon(Icons.timer_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Reenviar código en ${secondsRemaining}s',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: isLoading ? null : onReenviarOtp,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reenviar código'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          CosmolButton(
            text: 'Verificar Código',
            isLoading: isLoading,
            onPressed: onVerificarOtp,
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: onVolverPaso2,
            child: const Text('Cambiar canal de envío'),
          ),
        ],
      ),
    );
  }
}
