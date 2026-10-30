import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cambiar_pin_provider.dart';

class CambiarPinScreen extends ConsumerStatefulWidget {
  const CambiarPinScreen({super.key});

  @override
  ConsumerState<CambiarPinScreen> createState() => _CambiarPinScreenState();
}

class _CambiarPinScreenState extends ConsumerState<CambiarPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualPinController = TextEditingController();
  final _nuevoPinController = TextEditingController();
  final _confirmarPinController = TextEditingController();

  @override
  void dispose() {
    _actualPinController.dispose();
    _nuevoPinController.dispose();
    _confirmarPinController.dispose();
    super.dispose();
  }

  Future<void> _handleGuardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(cambiarPinProvider.notifier);
    final exito = await notifier.cambiarPin(
      pinActual: _actualPinController.text,
      nuevoPin: _nuevoPinController.text,
      confirmarPin: _confirmarPinController.text,
    );

    if (mounted && exito) {
      _mostrarDialogoExito();
    }
  }

  void _mostrarDialogoExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.successGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '¡PIN Actualizado!',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tu PIN de acceso ha sido actualizado exitosamente. Utilízalo la próxima vez que inicies sesión.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CosmolButton(
              text: 'Aceptar',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarRecuperacionPorOtp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Olvidaste tu PIN actual?',
          style: AppTextStyles.subtitle1.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Para restablecer tu clave mediante el código de verificación por WhatsApp o SMS, cerraremos tu sesión actual para validar tu titularidad de forma segura.\n\n¿Deseas continuar?',
          style: AppTextStyles.body2.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                context.go('/recuperar-password');
              }
            },
            child: const Text('Continuar a Recuperación'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cambiarPinProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const CosmolAppBar(
        title: 'Cambiar PIN de Acceso',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta Encabezado Informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seguridad de la Cuenta',
                              style: AppTextStyles.subtitle2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ingresa tu clave actual y define un nuevo PIN numérico de 4 a 6 dígitos.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Banner de Error
                if (state.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Campo PIN Actual
                CosmolTextField(
                  label: 'PIN Actual',
                  hint: '••••',
                  controller: _actualPinController,
                  isPassword: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa tu PIN actual';
                    }
                    if (v.trim().length < 4) {
                      return 'Mínimo 4 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Nuevo PIN
                CosmolTextField(
                  label: 'Nuevo PIN',
                  hint: '••••',
                  controller: _nuevoPinController,
                  isPassword: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.vpn_key_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa el nuevo PIN';
                    }
                    if (v.trim().length < 4) {
                      return 'Mínimo 4 dígitos';
                    }
                    if (v.trim() == _actualPinController.text.trim()) {
                      return 'El nuevo PIN no puede ser igual al actual';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Confirmar Nuevo PIN
                CosmolTextField(
                  label: 'Confirmar Nuevo PIN',
                  hint: '••••',
                  controller: _confirmarPinController,
                  isPassword: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icons.check_circle_outline_rounded,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Confirma el nuevo PIN';
                    }
                    if (v.trim() != _nuevoPinController.text.trim()) {
                      return 'Los números no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Botón Guardar
                CosmolButton(
                  text: 'Guardar Nuevo PIN',
                  isLoading: state.isLoading,
                  onPressed: _handleGuardar,
                ),
                const SizedBox(height: 20),

                // Enlace "¿Olvidaste tu PIN actual?"
                Center(
                  child: TextButton(
                    onPressed: _confirmarRecuperacionPorOtp,
                    child: Text(
                      '¿Olvidaste tu PIN actual?',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
