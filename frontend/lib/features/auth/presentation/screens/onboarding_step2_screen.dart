import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_step2_stepper.dart';
import '../widgets/verified_phone_card.dart';
import '../widgets/bill_guide_card.dart';

/// Pantalla del Paso 2 de Registro y Vinculación de Suministro
/// Basada exactamente en la guía visual de vista_registro_paso2.txt
class OnboardingStep2Screen extends ConsumerStatefulWidget {
  const OnboardingStep2Screen({super.key});

  @override
  ConsumerState<OnboardingStep2Screen> createState() =>
      _OnboardingStep2ScreenState();
}

class _OnboardingStep2ScreenState extends ConsumerState<OnboardingStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _socioCodeController = TextEditingController();
  final _ciController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _socioCodeController.dispose();
    _ciController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(onboardingProvider.notifier);
    final success = await notifier.completarRegistro(
      codSocio: _socioCodeController.text.trim(),
      ci: _ciController.text.trim(),
      username: _usernameController.text.trim(),
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
              'Tu suministro ha sido vinculado y tu cuenta ha sido creada correctamente.',
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
                'Tu C.I. ha sido deshabilitada como clave. A partir de ahora ingresa con tu usuario o Código de Socio y tu contraseña personal.',
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
                // Stepper: Paso 1 completado, Paso 2 activo
                const OnboardingStep2Stepper(),
                const SizedBox(height: 14),

                // Tarjeta de teléfono verificado
                VerifiedPhoneCard(telefono: onboardingState.telefono),
                const SizedBox(height: 14),

                // Formulario Principal de Vinculación
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
            // Título y Subtítulo
            Text(
              'Vincula tus datos',
              style: AppTextStyles.h2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa los datos de tu cuenta de agua potable de COSMOL R.L.',
              style: AppTextStyles.body1.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta de contexto con guía visual
            const BillGuideCard(),
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
                  return 'Ingrese su C.I. registrado en COSMOL';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Campo 3: Crear Nombre de Usuario
            CosmolTextField(
              label: 'Crear Nombre de Usuario',
              controller: _usernameController,
              keyboardType: TextInputType.text,
              prefixIcon: Icons.alternate_email,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese un nombre de usuario';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Campo 4: Crear Contraseña de Acceso
            CosmolTextField(
              label: 'Crear Contraseña de Acceso',
              hint: 'Mínimo 4 caracteres',
              controller: _passwordController,
              isPassword: true,
              prefixIcon: Icons.lock_outline,
              validator: (val) {
                if (val == null || val.trim().length < 4) {
                  return 'La contraseña debe tener al menos 4 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Mensaje informativo de padrón oficial
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
                    Icons.verified_user,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los datos deben coincidir exactamente con los datos registrados en COSMOL R.L. La vinculación autoriza la consulta y pago de avisos de cobranza.',
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

            // Error banner si existe
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
              loadingText: 'Vinculando Suministro...',
              suffixIcon: Icons.arrow_forward,
              isLoading: state.isLoading,
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
