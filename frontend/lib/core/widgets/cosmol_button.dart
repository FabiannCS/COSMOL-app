import 'package:flutter/material.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_text_styles.dart';

enum CosmolButtonType { primary, secondary, outline, text }

/// Botón institucional reutilizable con soporte para bordes redondeados completos (pill),
/// íconos sufijos/prefijos e indicador de carga integrados.
class CosmolButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CosmolButtonType type;
  final bool isLoading;
  final String? loadingText;
  final IconData? icon;
  final IconData? suffixIcon;
  final double? width;
  final double height;
  final bool isFullRounded;

  const CosmolButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CosmolButtonType.primary,
    this.isLoading = false,
    this.loadingText,
    this.icon,
    this.suffixIcon,
    this.width,
    this.height = 52,
    this.isFullRounded = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;
    final borderRadius = isFullRounded ? BorderRadius.circular(9999) : BorderRadius.circular(12);

    Widget childWidget = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_getSpinnerColor()),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              loadingText ?? 'Procesando...',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.button.copyWith(
                color: _getTextColor(isDisabled),
              ),
            ),
          ),
        ] else ...[
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.button.copyWith(
                color: _getTextColor(isDisabled),
              ),
            ),
          ),
          if (suffixIcon != null) ...[
            const SizedBox(width: 8),
            Icon(suffixIcon, size: 20),
          ],
        ],
      ],
    );

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: _buildButtonByStyle(context, childWidget, isDisabled, borderRadius),
    );
  }

  Widget _buildButtonByStyle(
    BuildContext context,
    Widget child,
    bool isDisabled,
    BorderRadius borderRadius,
  ) {
    switch (type) {
      case CosmolButtonType.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            disabledBackgroundColor: AppColors.primaryContainer.withValues(alpha: 0.5),
            elevation: 1,
            shadowColor: AppColors.shadowColor,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
            ),
          ),
          child: child,
        );

      case CosmolButtonType.secondary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.5),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
            ),
          ),
          child: child,
        );

      case CosmolButtonType.outline:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: isDisabled
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primary,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
            ),
          ),
          child: child,
        );

      case CosmolButtonType.text:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
            ),
          ),
          child: child,
        );
    }
  }

  Color _getTextColor(bool isDisabled) {
    if (isDisabled && type != CosmolButtonType.primary && type != CosmolButtonType.secondary) {
      return AppColors.textMuted;
    }

    switch (type) {
      case CosmolButtonType.primary:
      case CosmolButtonType.secondary:
        return AppColors.pureWhite;
      case CosmolButtonType.outline:
        return AppColors.primary;
      case CosmolButtonType.text:
        return AppColors.secondary;
    }
  }

  Color _getSpinnerColor() {
    switch (type) {
      case CosmolButtonType.primary:
      case CosmolButtonType.secondary:
        return AppColors.pureWhite;
      case CosmolButtonType.outline:
        return AppColors.primary;
      case CosmolButtonType.text:
        return AppColors.secondary;
    }
  }
}
