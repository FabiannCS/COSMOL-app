import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../providers/recuperar_password_provider.dart';
import '../widgets/recuperar_paso1_identificacion_card.dart';
import '../widgets/recuperar_paso2_canal_card.dart';
import '../widgets/recuperar_paso3_otp_card.dart';
import '../widgets/recuperar_paso4_pin_card.dart';
import '../widgets/recuperar_password_stepper.dart';
import '../widgets/recuperar_password_success_dialog.dart';

/// Pantalla Principal de Recuperación de Contraseña / PIN (COSMOL R.L.)
/// Orquesta el flujo modular Zero-Trust Phone Binding en 4 pasos.
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
      RecuperarPasswordSuccessDialog.show(
        context,
        onIniciarSesion: () {
          ref.read(recuperarPasswordProvider.notifier).reset();
          context.go('/login');
        },
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recuperarPasswordProvider);
    final notifier = ref.read(recuperarPasswordProvider.notifier);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          notifier.reset();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: CosmolAppBar(
          title: 'COSMOL R.L.',
          subtitle: 'Recuperar Contraseña',
          showBackButton: true,
          onBackPressed: () {
            notifier.reset();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecuperarPasswordStepper(currentStep: state.currentStep),
                const SizedBox(height: 16),

                if (state.errorMessage != null) ...[
                  _buildErrorBanner(state.errorMessage!),
                  const SizedBox(height: 16),
                ],

                if (state.currentStep == 1)
                  RecuperarPaso1IdentificacionCard(
                    formKey: _formKeyStep1,
                    socioCodeController: _socioCodeController,
                    ciController: _ciController,
                    isLoading: state.isLoading,
                    onValidar: _handleStep1Validar,
                  ),

                if (state.currentStep == 2)
                  RecuperarPaso2CanalCard(
                    codSocio: state.codSocio,
                    nombreTitular: state.nombreTitular,
                    telefonoEnmascarado: state.telefonoEnmascarado,
                    canal: state.canal,
                    isLoading: state.isLoading,
                    onCanalChanged: notifier.setCanal,
                    onEnviarOtp: _handleStep2EnviarOtp,
                    onVolverPaso1: () => notifier.setStep(1),
                  ),

                if (state.currentStep == 3)
                  RecuperarPaso3OtpCard(
                    otpController: _otpController,
                    canal: state.canal,
                    telefonoEnmascarado: state.telefonoEnmascarado,
                    canResend: state.canResend,
                    secondsRemaining: state.secondsRemaining,
                    isLoading: state.isLoading,
                    onVerificarOtp: _handleStep3VerificarOtp,
                    onReenviarOtp: notifier.reenviarOtp,
                    onVolverPaso2: () => notifier.setStep(2),
                  ),

                if (state.currentStep == 4)
                  RecuperarPaso4PinCard(
                    formKey: _formKeyStep4,
                    pinController: _pinController,
                    confirmPinController: _confirmPinController,
                    isLoading: state.isLoading,
                    onGuardarPin: _handleStep4CambiarPin,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
