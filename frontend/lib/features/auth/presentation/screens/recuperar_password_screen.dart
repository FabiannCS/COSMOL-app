import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/recuperar_password_provider.dart';
import '../widgets/verified_socio_card.dart';

/// Pantalla de Recuperación de Contraseña / PIN (COSMOL R.L.)
/// Implementa el flujo seguro Zero-Trust Phone Binding en 4 pasos progresivos.
class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState
    extends ConsumerState<RecuperarPasswordScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep4 = GlobalKey<FormState>();

  final _socioCodeController = TextEditingController();
  final _ciController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _socioCodeController.dispose();
    _ciController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleStep1Validar() async {
    if (!_formKeyStep1.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(recuperarPasswordProvider.notifier);
    await notifier.validarTitular(
      codSocio: _socioCodeController.text.trim(),
      ci: _ciController.text.trim(),
    );
  }

  Future<void> _handleStep2EnviarOtp() async {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(recuperarPasswordProvider.notifier);
    await notifier.solicitarOtp();
  }

  Future<void> _handleStep3VerificarOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el código de seguridad de 6 dígitos.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final notifier = ref.read(recuperarPasswordProvider.notifier);
    await notifier.verificarOtp(code);
  }

  Future<void> _handleStep4CambiarPin() async {
    if (!_formKeyStep4.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(recuperarPasswordProvider.notifier);
    final success = await notifier.cambiarPin(
      nuevoPin: _pinController.text.trim(),
      confirmarPin: _confirmPinController.text.trim(),
    );

    if (mounted && success) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              Navigator.of(ctx).pop();
              ref.read(recuperarPasswordProvider.notifier).reset();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recuperarPasswordProvider);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(recuperarPasswordProvider.notifier).reset();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: CosmolAppBar(
          title: 'COSMOL R.L.',
          subtitle: 'Recuperar Contraseña',
          showBackButton: true,
          onBackPressed: () {
            ref.read(recuperarPasswordProvider.notifier).reset();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProgressHeader(state.currentStep),
                const SizedBox(height: 16),

                if (state.errorMessage != null) ...[
                  _buildErrorBanner(state.errorMessage!),
                  const SizedBox(height: 16),
                ],

                if (state.currentStep == 1) _buildStep1(state),
                if (state.currentStep == 2) _buildStep2(state),
                if (state.currentStep == 3) _buildStep3(state),
                if (state.currentStep == 4) _buildStep4(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(int currentStep) {
    final stepTitles = [
      'Identificación',
      'Canal de Seguridad',
      'Código de Verificación',
      'Nueva Contraseña / PIN',
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

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body2.copyWith(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 1: VALIDACIÓN DE TITULAR (cod_socio + CI)
  // ---------------------------------------------------------------------------
  Widget _buildStep1(RecuperarPasswordState state) {
    return Form(
      key: _formKeyStep1,
      child: CosmolCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recuperar Contraseña',
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ingresa tu Código de Socio y Carnet de Identidad registrado en COSMOL para validar tu cuenta.',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            CosmolTextField(
              controller: _socioCodeController,
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
              controller: _ciController,
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
              isLoading: state.isLoading,
              onPressed: _handleStep1Validar,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 2: SELECCIÓN DE CANAL Y DESPACHO OTP
  // ---------------------------------------------------------------------------
  Widget _buildStep2(RecuperarPasswordState state) {
    final notifier = ref.read(recuperarPasswordProvider.notifier);

    return CosmolCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VerifiedSocioCard(
            codSocio: state.codSocio,
            nombreTitular: state.nombreTitular,
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
                  (state.telefonoEnmascarado != null && state.telefonoEnmascarado!.isNotEmpty)
                      ? state.telefonoEnmascarado!
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
                  subtitle: 'Recomendado',
                  isSelected: state.canal == 'WHATSAPP',
                  onTap: () => notifier.setCanal('WHATSAPP'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCanalOption(
                  icon: Icons.sms_outlined,
                  iconColor: AppColors.primary,
                  title: 'SMS',
                  subtitle: 'Mensaje de texto',
                  isSelected: state.canal == 'SMS',
                  onTap: () => notifier.setCanal('SMS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          CosmolButton(
            text: 'Enviar Código de Seguridad',
            isLoading: state.isLoading,
            onPressed: _handleStep2EnviarOtp,
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () => notifier.setStep(1),
            child: const Text('Volver a cambiar socio o C.I.'),
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

  // ---------------------------------------------------------------------------
  // PASO 3: VERIFICACIÓN DEL CÓDIGO OTP
  // ---------------------------------------------------------------------------
  Widget _buildStep3(RecuperarPasswordState state) {
    final notifier = ref.read(recuperarPasswordProvider.notifier);

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
                child: const Icon(Icons.mark_email_read_outlined, color: AppColors.successGreen, size: 24),
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
                      'Vía ${state.canal == "WHATSAPP" ? "WhatsApp" : "SMS"}${(state.telefonoEnmascarado != null && state.telefonoEnmascarado!.isNotEmpty) ? " al ${state.telefonoEnmascarado}" : " a su número registrado"}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
            controller: _otpController,
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
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (val) {
              if (val.length == 6) {
                _handleStep3VerificarOtp();
              }
            },
          ),
          const SizedBox(height: 16),

          // Reenvío de código y timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.canResend) ...[
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Reenviar código en ${state.secondsRemaining}s',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: state.isLoading ? null : () => notifier.reenviarOtp(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reenviar código'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          CosmolButton(
            text: 'Verificar Código',
            isLoading: state.isLoading,
            onPressed: _handleStep3VerificarOtp,
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () => notifier.setStep(2),
            child: const Text('Cambiar canal de envío'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PASO 4: CREACIÓN DE NUEVA CONTRASEÑA / PIN
  // ---------------------------------------------------------------------------
  Widget _buildStep4(RecuperarPasswordState state) {
    return Form(
      key: _formKeyStep4,
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
                  child: const Icon(Icons.password, color: AppColors.primary, size: 24),
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
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Crea una contraseña o PIN seguro de al menos 4 caracteres para iniciar sesión en tu cuenta.',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            CosmolTextField(
              controller: _pinController,
              label: 'Nuevo PIN o Contraseña',
              hint: 'Mínimo 4 caracteres',
              isPassword: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingrese su nuevo PIN';
                if (v.trim().length < 4) return 'Mínimo 4 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            CosmolTextField(
              controller: _confirmPinController,
              label: 'Confirmar Nuevo PIN',
              hint: 'Repita el mismo PIN',
              isPassword: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Confirme su nuevo PIN';
                if (v.trim() != _pinController.text.trim()) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            CosmolButton(
              text: 'Guardar Nueva Contraseña',
              isLoading: state.isLoading,
              onPressed: _handleStep4CambiarPin,
            ),
          ],
        ),
      ),
    );
  }
}
