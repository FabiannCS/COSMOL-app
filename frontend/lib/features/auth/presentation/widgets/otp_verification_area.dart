import 'package:flutter/material.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_text_styles.dart';

class OtpVerificationArea extends StatefulWidget {
  final int secondsRemaining;
  final bool canResend;
  final ValueChanged<String>? onOtpChanged;
  final VoidCallback? onResend;

  const OtpVerificationArea({
    super.key,
    required this.secondsRemaining,
    this.canResend = false,
    this.onOtpChanged,
    this.onResend,
  });

  @override
  State<OtpVerificationArea> createState() => _OtpVerificationAreaState();
}

class _OtpVerificationAreaState extends State<OtpVerificationArea> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _notifyOtp() {
    final code = _controllers.map((c) => c.text).join();
    widget.onOtpChanged?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final mins =
        (widget.secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs =
        (widget.secondsRemaining % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Código de Verificación',
              style: AppTextStyles.subtitle2.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: const [
                Icon(Icons.check, color: AppColors.successGreen, size: 16),
                SizedBox(width: 4),
                Text(
                  'Enviado',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < 5 ? 6.0 : 0.0,
                ),
                child: _buildOtpBox(index),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ingresa el código de 6 dígitos enviado a tu celular.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.canResend
                            ? '¿No recibiste el código?'
                            : 'Reenviar código en ',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.canResend)
                      Text(
                        '$mins:$secs',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.canResend ? widget.onResend : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Reenviar',
                    style: AppTextStyles.caption.copyWith(
                      color: widget.canResend
                          ? AppColors.primary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _focusNodes[index].hasFocus
              ? AppColors.primary
              : AppColors.surfaceContainerHigh,
        ),
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w900,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) {
            if (val.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (val.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            _notifyOtp();
          },
        ),
      ),
    );
  }
}
