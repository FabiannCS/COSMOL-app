import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';

class ReconexionTicketScreen extends StatelessWidget {
  final int idReconexion;
  final String? estado;
  final String? codSocio;

  const ReconexionTicketScreen({
    super.key,
    required this.idReconexion,
    this.estado,
    this.codSocio,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const CosmolAppBar(
        title: 'Comprobante de Solicitud',
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CosmolCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successBackground,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.successGreen),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: AppColors.successGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Solicitud Registrada',
                        style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Su solicitud de reconexión ha sido registrada exitosamente.',
                        style: AppTextStyles.body2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'NÚMERO DE TICKET',
                              style: AppTextStyles.caption.copyWith(letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '#$idReconexion',
                              style: AppTextStyles.h1.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.warningBackground,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.warningOrange),
                              ),
                              child: Text(
                                estado ?? 'PENDIENTE',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.warningOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (codSocio != null && codSocio!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Socio:', style: AppTextStyles.caption),
                            Text(
                              'Socio #$codSocio',
                              style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Un técnico atenderá la reconexión de su servicio en los plazos establecidos.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      CosmolButton(
                        text: 'Volver al Inicio',
                        onPressed: () => context.go('/dashboard'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
