import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/account_locked_dialog.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/auth_provider.dart';

/// Pantalla de Inicio de Sesión de Socios COSMOL R.L.
/// Basada exactamente en la guía visual de vista_login_cosmol.txt
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _socioCodeController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final savedSocio =
          await ref.read(storageServiceProvider).getActiveCodSocio();
      if (savedSocio != null && savedSocio.isNotEmpty && mounted) {
        _socioCodeController.text = savedSocio;
      }
    });
  }

  @override
  void dispose() {
    _socioCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final success = await ref.read(authProvider.notifier).login(
          codSocio: _socioCodeController.text.trim(),
          password: _passwordController.text.trim(),
        );

    if (mounted && success) {
      context.go('/dashboard');
    }
  }

  Future<void> _openWhatsAppHelp() async {
    final Uri url = Uri.parse(
      'https://wa.me/59178500000?text=Hola%20COSMOL%20R.L.%2C%20requiero%20asistencia%20con%20mi%20c%C3%B3digo%20de%20socio%20o%20clave',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.locked) {
        AccountLockedDialog.show(
          context,
          segundosRestantes: next.bloqueadoSegundosRestantes,
          onUnlockViaOtp: () {
            context.push('/onboarding');
          },
        );
      } else if (next.status == AuthStatus.onboardingRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage ?? 'Debe completar el registro de su cuenta.',
            ),
            backgroundColor: AppColors.secondary,
          ),
        );
        context.push('/onboarding');
      } else if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage &&
          next.status != AuthStatus.locked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    });
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- Brand Header ---
                  _buildBrandHeader(),
                  const SizedBox(height: 24),

                  // --- Login Card Surface ---
                  CosmolCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Campo 1: Usuario / Código de Socio
                          CosmolTextField(
                            label: 'Usuario',
                            hint: 'Ingrese su Usuario',
                            controller: _socioCodeController,
                            keyboardType: TextInputType.text,
                            prefixIcon: Icons.badge_outlined,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese su Usuario o Código de Socio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Campo 2: Contraseña
                          CosmolTextField(
                            label: 'Contraseña',
                            hint: 'Ingrese su contraseña',
                            controller: _passwordController,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese su contraseña o PIN';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Security Warning Notice (3 Intentos)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: AppTextStyles.body2.copyWith(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: 'Bloqueo preventivo tras ',
                                        ),
                                        TextSpan(
                                          text: '3 intentos fallidos',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                        TextSpan(text: '.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Submit Button (Ingresar a mi Cuenta)
                          CosmolButton(
                            text: 'Ingresar a mi Cuenta',
                            loadingText: 'Verificando Credenciales...',
                            suffixIcon: Icons.arrow_forward,
                            isLoading: authState.isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 16),

                          // Help Link (¿Olvidaste tu contraseña?)
                          Center(
                            child: InkWell(
                              onTap: _openWhatsAppHelp,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.help_outline,
                                      size: 18,
                                      color: AppColors.secondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '¿Olvidaste tu contraseña?',
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.subtitle2.copyWith(
                                          fontSize: 13,
                                          color: AppColors.secondary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(color: AppColors.borderSubtle, height: 1),
                          const SizedBox(height: 20),

                          // Secondary Button (Registrarse / Primer Acceso)
                          CosmolButton(
                            text: 'Registrarse',
                            type: CosmolButtonType.outline,
                            icon: Icons.person_add_alt_1_outlined,
                            onPressed: () {
                              context.push('/onboarding');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo_cosmol.jpeg',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.water_drop_rounded,
              color: AppColors.primary,
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'COSMOL R.L.',
          style: AppTextStyles.h1.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
