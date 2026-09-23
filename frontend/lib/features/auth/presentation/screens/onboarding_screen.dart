import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_progress_tracker.dart';

/// Pantalla del Paso 1 de Registro: Verificación de Código de Socio y C.I.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _socioCodeController = TextEditingController();
  final _ciController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    if (state.codSocio.isNotEmpty) {
      _socioCodeController.text = state.codSocio;
    }
    if (state.ci.isNotEmpty) {
      _ciController.text = state.ci;
    }
  }

  @override
  void dispose() {
    _socioCodeController.dispose();
    _ciController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifySocio() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(onboardingProvider.notifier);
    final success = await notifier.verificarSocio(
      codSocio: _socioCodeController.text.trim(),
      ci: _ciController.text.trim(),
    );

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
        appBar: CosmolAppBar(
          title: 'COSMOL R.L.',
          subtitle: 'Registro De Socio',
          showBackButton: true,
          onBackPressed: () {
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
                const OnboardingProgressTracker(),
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
              'Identificación de Socio',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa tu Código de Socio y tu C.I. registrado en COSMOL R.L.',
              style: AppTextStyles.body1.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Campo 1: Código de Socio
            CosmolTextField(
              label: 'Código de Socio',
              controller: _socioCodeController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.badge_outlined,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese su Código de Socio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Campo 2: Cédula de Identidad (C.I.)
            CosmolTextField(
              label: 'Cédula de Identidad (C.I.)',
              controller: _ciController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.credit_card,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese su C.I. registrado';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Aviso de padrón oficial
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
                    Icons.verified_user_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Validaremos tus datos con los que se tienen registrados en los archivos de COSMOL R.L. para el registro de tu cuenta.',
                      style: AppTextStyles.body2.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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

            // Botón Continuar
            CosmolButton(
              text: 'Continuar',
              loadingText: 'Verificando Socio...',
              suffixIcon: Icons.arrow_forward,
              isLoading: state.isLoading,
              onPressed: _handleVerifySocio,
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
      ),
    );
  }
}
