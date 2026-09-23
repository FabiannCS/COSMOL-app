import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                color: AppColors.primaryBlue,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'COSMOL R.L.',
              style: AppTextStyles.h1.copyWith(
                color: AppColors.pureWhite,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cooperativa de Servicios Públicos Montero',
              style: AppTextStyles.subtitle2.copyWith(
                color: AppColors.accentTurquoise,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTurquoise),
            ),
          ],
        ),
      ),
    );
  }
}
