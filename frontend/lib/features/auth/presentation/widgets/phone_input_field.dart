import 'package:flutter/material.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_text_styles.dart';

class PhoneInputField extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const PhoneInputField({
    super.key,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceContainerLow),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // Bandera de Bolivia simulada con colores
                Container(
                  width: 20,
                  height: 14,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: Container(color: Colors.red)),
                      Expanded(child: Container(color: Colors.yellow)),
                      Expanded(child: Container(color: Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+591',
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: TextInputType.phone,
              maxLength: 8,
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintStyle: AppTextStyles.subtitle1.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
