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
import '../providers/migrar_celular_provider.dart';

/// Pantalla de Migración de Teléfono Celular (COSMOL R.L.)
/// Permite al socio titular actualizar su número de teléfono vinculado
/// validando primero sus credenciales (Código, CI y PIN actual)
/// y confirmando el traspaso mediante un código OTP recibido en el nuevo celular.
class MigrarCelularScreen extends ConsumerStatefulWidget {
  final String? initialCodSocio;
  final String? initialCi;
  final String? nombreTitular;

  const MigrarCelularScreen({
    super.key,
    this.initialCodSocio,
    this.initialCi,
    this.nombreTitular,
  });

  @override
  ConsumerState<MigrarCelularScreen> createState() => _MigrarCelularScreenState();
}

class _MigrarCelularScreenState extends ConsumerState<MigrarCelularScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();

  late final TextEditingController _socioCodeController;
  late final TextEditingController _ciController;
  final _pinActualController = TextEditingController();
  final _nuevoTelefonoController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _socioCodeController =
        TextEditingController(text: widget.initialCodSocio ?? '');
    _ciController = TextEditingController(text: widget.initialCi ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(migrarCelularProvider.notifier).inicializar(
            codSocio: widget.initialCodSocio,
            ci: widget.initialCi,
            nombreTitular: widget.nombreTitular,
          );
    });
  }

  @override
  void dispose() {
    _socioCodeController.dispose();
    _ciController.dispose();
    _pinActualController.dispose();
    _nuevoTelefonoController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleIniciarMigracion() async {
    if (!_formKeyStep1.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(migrarCelularProvider.notifier);
    await notifier.iniciarMigracion(
      codSocio: _socioCodeController.text.trim(),
      ci: _ciController.text.trim(),
      pinActual: _pinActualController.text.trim(),
      nuevoTelefono: _nuevoTelefonoController.text.trim(),
    );
  }

  Future<void> _handleConfirmarOtp() async {
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

    final notifier = ref.read(migrarCelularProvider.notifier);
    final success = await notifier.confirmarOtp(code);

    if (mounted && success) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    final state = ref.read(migrarCelularProvider);
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
                '¡Migración Exitosa!',
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
              'Tu cuenta ha sido vinculada satisfactoriamente a tu nuevo número de teléfono (+591 ${state.nuevoTelefono}).',
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Por seguridad, las sesiones abiertas en dispositivos anteriores han sido cerradas automáticamente.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: CosmolButton(
              text: 'Ingresar a la Aplicación',
              icon: Icons.arrow_forward,
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/dashboard');
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(migrarCelularProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: CosmolAppBar(
        title: 'COSMOL R.L.',
        subtitle: 'Migración De Teléfono',
        showBackButton: true,
        onBackPressed: () {
          if (state.currentStep == 2) {
            ref.read(migrarCelularProvider.notifier).volverAlPaso1();
          } else {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          }
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressIndicator(state.currentStep),
              const SizedBox(height: 16),
              if (state.currentStep == 1)
                _buildStep1Form(state)
              else
                _buildStep2Otp(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepCircle(
            stepNumber: 1,
            label: 'Credenciales',
            isActive: currentStep == 1,
            isCompleted: currentStep > 1,
          ),
          Expanded(
            child: Container(
              height: 2,
              color: currentStep > 1 ? AppColors.primary : Colors.grey[300],
            ),
          ),
          _buildStepCircle(
            stepNumber: 2,
            label: 'Verificación OTP',
            isActive: currentStep == 2,
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required int stepNumber,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    final bgColor = isCompleted
        ? AppColors.primary
        : (isActive ? AppColors.primary : Colors.grey[200]!);
    final textColor = isCompleted || isActive ? Colors.white : Colors.grey[600]!;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
            color: isActive || isCompleted ? AppColors.primary : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Form(MigrarCelularState state) {
    final titular = widget.nombreTitular ?? state.nombreTitular;

    return CosmolCard(
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phonelink_setup,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actualizar Celular',
                        style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Paso 1: Validación de Titularidad',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (titular != null && titular.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        titular,
                        style: AppTextStyles.body2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Por motivos de seguridad, para migrar tu cuenta a un nuevo número debes confirmar tu Cédula de Identidad y tu PIN actual.',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Código de Socio
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
            const SizedBox(height: 14),

            // Cédula de Identidad
            CosmolTextField(
              label: 'Cédula de Identidad (C.I.)',
              controller: _ciController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.credit_card,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese su C.I.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // PIN actual
            CosmolTextField(
              label: 'Contraseña / PIN Actual',
              controller: _pinActualController,
              isPassword: true,
              prefixIcon: Icons.lock_outline,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese su contraseña o PIN actual';
                }
                if (val.trim().length < 4) {
                  return 'El PIN debe tener al menos 4 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Nuevo Teléfono Celular
            CosmolTextField(
              label: 'Nuevo Número Celular',
              hint: 'Ej: 71234567 (8 dígitos)',
              controller: _nuevoTelefonoController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Ingrese su nuevo número celular';
                }
                if (val.trim().length < 8) {
                  return 'El celular debe tener 8 dígitos';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Selector de Canal
            Text(
              'Canal para recibir el código de verificación:',
              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCanalOption(
                    canal: 'WHATSAPP',
                    label: 'WhatsApp',
                    icon: Icons.chat_bubble_outline,
                    isSelected: state.canal == 'WHATSAPP',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCanalOption(
                    canal: 'SMS',
                    label: 'Mensaje SMS',
                    icon: Icons.sms_outlined,
                    isSelected: state.canal == 'SMS',
                  ),
                ),
              ],
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

            CosmolButton(
              text: 'Continuar y Enviar Código',
              loadingText: 'Verificando datos...',
              icon: Icons.send_rounded,
              isLoading: state.isLoading,
              onPressed: _handleIniciarMigracion,
            ),
            const SizedBox(height: 14),

            Center(
              child: TextButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/login');
                  }
                },
                child: const Text('Cancelar y Volver al Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanalOption({
    required String canal,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(migrarCelularProvider.notifier).setCanal(canal);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Otp(MigrarCelularState state) {
    return CosmolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código de Seguridad',
                      style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Paso 2: Confirmar nuevo número',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Ingresa el código de 6 dígitos que enviamos vía ${state.canal} al nuevo número:',
            style: AppTextStyles.body2,
          ),
          const SizedBox(height: 6),
          Text(
            '+591 ${state.nuevoTelefono}',
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Campo OTP de 6 dígitos
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.grey[300],
                letterSpacing: 10,
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Banner de debug en desarrollo
          if (state.debugCodigoOtp != null && state.debugCodigoOtp!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Código de prueba: ${state.debugCodigoOtp}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _otpController.text = state.debugCodigoOtp!;
                    },
                    child: const Text('Autocompletar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Temporizador de reenvío
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.canResend) ...[
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Reenviar código en ${state.secondsRemaining}s',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () {
                    ref.read(migrarCelularProvider.notifier).reenviarOtp();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reenviar código OTP'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

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

          CosmolButton(
            text: 'Confirmar y Finalizar',
            loadingText: 'Validando código...',
            icon: Icons.check,
            isLoading: state.isLoading,
            onPressed: _handleConfirmarOtp,
          ),
          const SizedBox(height: 12),

          Center(
            child: TextButton.icon(
              onPressed: () {
                ref.read(migrarCelularProvider.notifier).volverAlPaso1();
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Corregir número o datos'),
            ),
          ),
        ],
      ),
    );
  }
}
