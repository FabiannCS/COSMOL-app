import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_text_styles.dart';
import 'cosmol_button.dart';

/// Modal de seguridad cuando la cuenta es bloqueada por 3 intentos fallidos.
class AccountLockedDialog extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback? onUnlockViaOtp;

  const AccountLockedDialog({
    super.key,
    required this.initialSeconds,
    this.onUnlockViaOtp,
  });

  static Future<void> show(
    BuildContext context, {
    required int segundosRestantes,
    VoidCallback? onUnlockViaOtp,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AccountLockedDialog(
        initialSeconds: segundosRestantes,
        onUnlockViaOtp: onUnlockViaOtp,
      ),
    );
  }

  @override
  State<AccountLockedDialog> createState() => _AccountLockedDialogState();
}

class _AccountLockedDialogState extends State<AccountLockedDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.errorBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_outlined,
                  color: AppColors.errorRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cuenta Bloqueada Temporalmente',
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ha superado los 3 intentos fallidos consecutivos. Por motivos de seguridad, su cuenta ha sido suspendida temporalmente.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body2,
              ),
              const SizedBox(height: 20),
              // Temporizador
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Tiempo restante de espera:',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.darkNavy,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Acciones
              CosmolButton(
                text: widget.onUnlockViaOtp != null
                    ? 'Desbloquear de inmediato vía OTP'
                    : 'Entendido',
                icon: Icons.lock_reset,
                type: CosmolButtonType.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.onUnlockViaOtp != null) {
                    widget.onUnlockViaOtp!();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
