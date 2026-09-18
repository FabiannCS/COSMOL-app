import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_progress_tracker.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/otp_verification_area.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _phoneController = TextEditingController();
  String _enteredOtp = '';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      ref
          .read(onboardingProvider.notifier)
          .setTelefono(_phoneController.text.trim());
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final notifier = ref.read(onboardingProvider.notifier);
    await notifier.solicitarOtp();
  }

  Future<void> _handleContinue() async {
    final state = ref.read(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (!state.otpSent) {
      await _handleSendCode();
      return;
    }

    if (_enteredOtp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el código de verificación de 4 dígitos.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final success = await notifier.verificarOtp(_enteredOtp);
    if (mounted && success) {
      context.push('/onboarding/step2');
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: AppColors.cardSurface.withValues(alpha: 0.9),
          elevation: 1,
          shadowColor: AppColors.shadowColor,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COSMOL R.L.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Registro De Socio',
                style: AppTextStyles.subtitle1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.pureWhite,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/logo_cosmol.jpeg',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.water_drop_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingProgressTracker(),
                const SizedBox(height: 16),
                _buildMainCard(onboardingState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(OnboardingState state) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Verifica tu Teléfono Móvil',
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Te enviaremos un código de seguridad para validar tu cuenta de socio.',
            style: AppTextStyles.body1.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Número Celular',
            style: AppTextStyles.subtitle2.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          PhoneInputField(
            controller: _phoneController,
          ),
          const SizedBox(height: 16),

          // Botón Enviar Código
          ElevatedButton(
            onPressed: state.isLoading ? null : _handleSendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5DC6FE),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              state.otpSent
                  ? 'Código Enviado vía ${state.canal}'
                  : 'Enviar Código por SMS / WhatsApp',
              style: AppTextStyles.button.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.errorMessage!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          if (state.otpSent) ...[
            const SizedBox(height: 24),
            OtpVerificationArea(
              secondsRemaining: state.secondsRemaining,
              canResend: state.canResend,
              onResend: _handleSendCode,
              onOtpChanged: (code) {
                _enteredOtp = code;
                if (code.length == 4) {
                  ref.read(onboardingProvider.notifier).verificarOtp(code);
                }
              },
            ),
          ],

          const SizedBox(height: 32),

          // Botón Continuar
          CosmolButton(
            text: 'Continuar',
            loadingText: 'Verificando Código...',
            suffixIcon: Icons.arrow_forward,
            isLoading: state.isLoading && state.otpSent,
            onPressed: _handleContinue,
          ),
          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/login');
                }
              },
              child: RichText(
                text: TextSpan(
                  text: '¿Ya tienes cuenta? ',
                  style: AppTextStyles.body2,
                  children: [
                    TextSpan(
                      text: 'Iniciar Sesión',
                      style: AppTextStyles.subtitle1.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
