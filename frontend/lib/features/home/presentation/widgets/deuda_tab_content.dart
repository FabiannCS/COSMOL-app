import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import 'balance_card_widget.dart';
import 'disruption_notice_card.dart';
import 'payment_channels_card.dart';

/// Contenido principal de la Pestaña 0: Deuda / Inicio del Dashboard.
class DeudaTabContent extends ConsumerWidget {
  final dynamic activeSuministro;
  final VoidCallback onVerRecibo;

  const DeudaTabContent({
    super.key,
    required this.activeSuministro,
    required this.onVerRecibo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codSocio = activeSuministro?.codSocio?.toString().trim() ?? '';
    final hasDebt = codSocio == '540';

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(multicuentaProvider.notifier).cargarSuministros();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner Flat
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Inicio',
                        style: AppTextStyles.subtitle2.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ],
                  ),
                  Text(
                    'Septiembre 2026',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta Principal de Balance (Modo Deuda vs Modo Al Día)
            BalanceCardWidget(
              hasDebt: hasDebt,
              onVerRecibo: onVerRecibo,
            ),
            const SizedBox(height: 16),

            // Aviso Preventivo de Corte (Solo si tiene deuda activa)
            if (hasDebt) ...[
              const DisruptionNoticeCard(),
              const SizedBox(height: 16),
            ],

            // Canales de Atención
            const PaymentChannelsCard(),
          ],
        ),
      ),
    );
  }
}
