import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_step2_stepper.dart';
import '../widgets/verified_socio_card.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/otp_verification_area.dart';

/// Pantalla del Paso 2 de Registro: Asociación de Teléfono, Verificación OTP y Creación de Credenciales
class OnboardingStep2Screen extends ConsumerStatefulWidget {
  const OnboardingStep2Screen({super.key});

  @override
  ConsumerState<OnboardingStep2Screen> createState() =>
      _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState extends ConsumerState<OnboardingStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    final notifier = ref.read(onboardingProvider.notifier);
    await notifier.solicitarOtp();
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final state = ref.read(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (!state.otpVerified && state.tokenOtpValido == null) {
      if (!state.otpSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor envíe y verifique el código de seguridad a su celular.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      } else if (_enteredOtp.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingrese el código completo de verificación de 6 dígitos.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      } else {
        await notifier.verificarOtp(_enteredOtp);
      }
      return;
    }

    final success = await notifier.completarRegistro(
      password: _passwordController.text.trim(),
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
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¡Registro Exitoso!',
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
              'Tu cuenta ha sido creada y tu suministro ha sido vinculado correctamente.',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Tu C.I. ha sido deshabilitada como clave. A partir de ahora ingresa con tu Código de Socio y tu nuevo PIN personal.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          CosmolButton(
            text: 'Ir a Iniciar Sesión',
            suffixIcon: Icons.login,
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/onboarding');
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
                context.go('/onboarding');
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
                const OnboardingStep2Stepper(),
                const SizedBox(height: 14),

                // Tarjeta de Socio Verificado en el Paso 1
                VerifiedSocioCard(
                  codSocio: onboardingState.codSocio.isNotEmpty
                      ? onboardingState.codSocio
                      : '104523',
                  nombreTitular: onboardingState.nombreTitular,
                ),
                const SizedBox(height: 14),

                _buildFormCard(onboardingState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(OnboardingState state) {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Teléfono y Credenciales',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Asocia tu celular para verificación de seguridad y crea tu usuario personal.',
              style: AppTextStyles.body1.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Sección 1: Teléfono Móvil
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
            const SizedBox(height: 14),

            // Selector de Canal Dual (WhatsApp / SMS)
            Text(
              'Canal de Entrega del Código',
              style: AppTextStyles.subtitle2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: state.isLoading
                        ? null
                        : () {
                            ref
                                .read(onboardingProvider.notifier)
                                .setCanal('WHATSAPP');
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: (state.canal.toUpperCase().contains('WHATSAPP') ||
                                state.canal == 'WhatsApp')
                            ? const Color(0xFFE8F5E9)
                            : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (state.canal.toUpperCase().contains('WHATSAPP') ||
                                  state.canal == 'WhatsApp')
                              ? const Color(0xFF25D366)
                              : AppColors.surfaceContainerHigh,
                          width: (state.canal.toUpperCase().contains('WHATSAPP') ||
                                  state.canal == 'WhatsApp')
                              ? 2
                              : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline,
                              color: Color(0xFF25D366), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'WhatsApp',
                            style: AppTextStyles.subtitle2.copyWith(
                              fontWeight: FontWeight.bold,
                              color: (state.canal
                                          .toUpperCase()
                                          .contains('WHATSAPP') ||
                                      state.canal == 'WhatsApp')
                                  ? const Color(0xFF1B5E20)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: state.isLoading
                        ? null
                        : () {
                            ref
                                .read(onboardingProvider.notifier)
                                .setCanal('SMS');
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: state.canal.toUpperCase() == 'SMS'
                            ? const Color(0xFFE1F5FE)
                            : AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: state.canal.toUpperCase() == 'SMS'
                              ? AppColors.primary
                              : AppColors.surfaceContainerHigh,
                          width: state.canal.toUpperCase() == 'SMS' ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sms_outlined,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'SMS',
                            style: AppTextStyles.subtitle2.copyWith(
                              fontWeight: FontWeight.bold,
                              color: state.canal.toUpperCase() == 'SMS'
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: state.isLoading ? null : _handleSendCode,
              icon: Icon(
                state.canal.toUpperCase() == 'SMS'
                    ? Icons.sms_outlined
                    : Icons.chat_bubble_outline,
                size: 20,
              ),
              label: Text(
                state.otpSent
                    ? 'Código Enviado por ${state.canal}'
                    : 'Enviar Código de Verificación',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5DC6FE),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),

            if (state.otpSent) ...[
              const SizedBox(height: 16),
              OtpVerificationArea(
                secondsRemaining: state.secondsRemaining,
                canResend: state.canResend,
                onResend: _handleSendCode,
                onOtpChanged: (code) {
                  _enteredOtp = code;
                  if (code.length == 6) {
                    ref.read(onboardingProvider.notifier).verificarOtp(code);
                  }
                },
              ),
            ],

            const SizedBox(height: 24),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 24),

            // Sección 2: Creación de Credenciales
            Text(
              'Crear PIN / Contraseña de Acceso',
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 14),

            // Campo: PIN o Contraseña de Acceso
            CosmolTextField(
              label: 'Nuevo PIN / Contraseña Personal',
              controller: _passwordController,
              isPassword: true,
              prefixIcon: Icons.lock_outline,
              validator: (val) {
                if (val == null || val.trim().length < 4) {
                  return 'El PIN o contraseña debe tener al menos 4 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.security,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Por seguridad, tu C.I. quedará invalidada como contraseña. En el día a día ingresarás con tu Código de Socio y tu nuevo PIN personal.',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (state.errorMessage != null) ...[
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
              const SizedBox(height: 16),
            ],

            // Botón Primario: Completar Registro
            CosmolButton(
              text: 'Completar Registro',
              loadingText: 'Creando Cuenta...',
              suffixIcon: Icons.arrow_forward,
              isLoading: state.isLoading && (state.otpVerified || state.tokenOtpValido != null),
              onPressed: _handleCompleteRegistration,
            ),
            const SizedBox(height: 12),

            // Botón Secundario: Volver al Paso 1
            CosmolButton(
              text: 'Volver al Paso 1',
              type: CosmolButtonType.outline,
              icon: Icons.arrow_back,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/onboarding');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
