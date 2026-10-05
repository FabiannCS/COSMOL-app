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
              width: 108,
              height: 108,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/LogoCosmolCuadrado.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.water_drop_rounded,
                    color: AppColors.primaryBlue,
                    size: 56,
                  ),
                ),
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
