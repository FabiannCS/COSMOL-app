import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/auth_provider.dart';

/// Pantalla de Inicio de Sesión de Socios COSMOL R.L.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _socioCodeController = TextEditingController();
  final _passwordController = TextEditingController();

  Timer? _lockTimer;
  int _segundosRestantes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final savedSocio =
          await ref.read(storageServiceProvider).getActiveCodSocio();
      if (savedSocio != null && savedSocio.isNotEmpty && mounted) {
        _socioCodeController.text = savedSocio;
      }

      final auth = ref.read(authProvider);
      if (auth.status == AuthStatus.locked && _lockTimer == null) {
        _iniciarContadorBloqueo(auth.bloqueadoSegundosRestantes);
      }
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _socioCodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _iniciarContadorBloqueo(int segundos) {
    _lockTimer?.cancel();
    final duracion = segundos > 0 ? segundos : 60;

    setState(() {
      _segundosRestantes = duracion;
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes > 1) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        timer.cancel();
        _lockTimer = null;
        setState(() {
          _segundosRestantes = 0;
        });
        ref.read(authProvider.notifier).unlockAccount();
      }
    });
  }

  String _formatSeconds(int seconds) {
    final int s = seconds > 0 ? seconds : 0;
    final int mins = s ~/ 60;
    final int secs = s % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _handleLogin() async {
    if (_segundosRestantes > 0) return;
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
      'https://wa.me/59161555507?text=Hola%20COSMOL%20R.L.%2C%20requiero%20asistencia%20con%20mi%20c%C3%B3digo%20de%20socio%20o%20clave',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bool isLocked =
        authState.status == AuthStatus.locked || _segundosRestantes > 0;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.locked || next.bloqueadoSegundosRestantes > 0) {
        if (_lockTimer == null || _segundosRestantes <= 0) {
          _iniciarContadorBloqueo(next.bloqueadoSegundosRestantes);
        }
      } else if (next.status == AuthStatus.onboardingRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage ?? 'Debe completar el registro de su cuenta.',
            ),
            backgroundColor: AppColors.secondary,
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
                          // Mensaje de Error Sobrio y Minimalista
                          _buildErrorBanner(authState),

                          // Campo 1: Código de Socio
                          CosmolTextField(
                            label: 'Código de Socio',
                            controller: _socioCodeController,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.badge_outlined,
                            onChanged: (_) {
                              if (ref.read(authProvider).errorMessage != null) {
                                ref.read(authProvider.notifier).clearError();
                              }
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese su Código de Socio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Campo 2: Contraseña
                          CosmolTextField(
                            label: 'Contraseña',
                            controller: _passwordController,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline,
                            onChanged: (_) {
                              if (ref.read(authProvider).errorMessage != null) {
                                ref.read(authProvider.notifier).clearError();
                              }
                            },
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese su contraseña o PIN';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Aviso Dinámico y Minimalista (Sin colores rojos)
                          _buildSecurityNotice(authState),
                          const SizedBox(height: 20),

                          // Submit Button (Ingresar a mi Cuenta)
                          CosmolButton(
                            text: isLocked ? 'Bloqueado' : 'Ingresar',
                            loadingText: 'Verificando Credenciales...',
                            suffixIcon: isLocked
                                ? Icons.lock_outline
                                : Icons.arrow_forward,
                            isLoading: authState.isLoading,
                            onPressed: isLocked ? null : _handleLogin,
                          ),
                          const SizedBox(height: 16),

                          // Help Link (¿Olvidaste tu contraseña?)
                          Center(
                            child: InkWell(
                              onTap: () {
                                context.push('/recuperar-password');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                          const Divider(
                              color: AppColors.borderSubtle, height: 1),
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
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              onPressed: _openWhatsAppHelp,
                              icon: const Icon(Icons.support_agent,
                                  size: 18, color: AppColors.textSecondary),
                              label: Text(
                                '¿Necesitas ayuda? Contactar Soporte',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
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

  /// Banner de Error: sobrio, conciso y minimalista
  Widget _buildErrorBanner(AuthState authState) {
    if (authState.errorMessage == null ||
        authState.status == AuthStatus.locked ||
        _segundosRestantes > 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos de acceso incorrectos',
                  style: AppTextStyles.subtitle2.copyWith(
                    color: AppColors.darkNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  authState.errorMessage!,
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => ref.read(authProvider.notifier).clearError(),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso de Seguridad Minimalista (Colores institucionales estándar, sin rojo)
  Widget _buildSecurityNotice(AuthState authState) {
    final bool isLocked =
        authState.status == AuthStatus.locked || _segundosRestantes > 0;

    // Si la cuenta está bloqueada pero el temporizador aún no ha sido inicializado:
    if (isLocked && _lockTimer == null && _segundosRestantes <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lockTimer == null) {
          _iniciarContadorBloqueo(authState.bloqueadoSegundosRestantes);
        }
      });
    }

    final int displaySeconds = _segundosRestantes > 0
        ? _segundosRestantes
        : (authState.bloqueadoSegundosRestantes > 0
            ? authState.bloqueadoSegundosRestantes
            : 60);

    // Estado 1: Cuenta temporalmente en pausa con Temporizador en Vivo Minimalista
    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 20,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cuenta pausada temporalmente',
                    style: AppTextStyles.subtitle2.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Límite de intentos alcanzado',
                    style: AppTextStyles.body2.copyWith(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                _formatSeconds(displaySeconds),
                style: AppTextStyles.subtitle2.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Estado 2: Intento(s) fallido(s) dinámico (1 o 2 fallos)
    if (authState.intentosFallidos > 0) {
      final int restantes = authState.intentosRestantes;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.body2.copyWith(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(
                      text: 'Intento ${authState.intentosFallidos} de 3. ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    TextSpan(
                      text: 'Le ${restantes == 1 ? 'queda 1 intento' : 'quedan $restantes intentos'} antes del bloqueo.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Estado 3: Estado inicial neutro (0 fallos)
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
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
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/LogoCosmolCuadrado.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.water_drop_rounded,
                color: AppColors.primary,
                size: 52,
              ),
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
