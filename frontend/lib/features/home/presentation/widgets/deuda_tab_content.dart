import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../deuda/presentation/providers/deuda_provider.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import 'balance_card_widget.dart';
import 'disruption_notice_card.dart';
import 'payment_channels_card.dart';

/// Contenido principal de la Pestaña 0: Deuda / Inicio del Dashboard conectado a datos reales.
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
    final deudaState = ref.watch(deudaProvider);
    final deudaNotifier = ref.read(deudaProvider.notifier);

    // Escuchar cambio de suministro activo para recargar la deuda
    ref.listen(multicuentaProvider.select((s) => s.activeSuministro), (prev, next) {
      if (next != null && (prev == null || prev.codSocio != next.codSocio)) {
        deudaNotifier.cargarDeuda(codSocio: next.codSocio, forzarRefresco: true);
      }
    });

    final deuda = deudaState.deuda;
    final codSocio = activeSuministro?.codSocio?.toString().trim() ?? '';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          ref.read(multicuentaProvider.notifier).cargarSuministros(),
          if (codSocio.isNotEmpty)
            deudaNotifier.cargarDeuda(codSocio: codSocio, forzarRefresco: true),
        ]);
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
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
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

            // Estado de Carga
            if (deudaState.isLoading && deuda == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 12),
                      Text(
                        'Consultando deuda en COSMOL...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (deudaState.errorMessage != null && deuda == null) ...[
              // Estado de Error
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.errorRed, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'No se pudo conectar con el sistema de cobranza',
                      style: AppTextStyles.subtitle2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.errorRed,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deudaState.errorMessage!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (codSocio.isNotEmpty) {
                          deudaNotifier.cargarDeuda(codSocio: codSocio, forzarRefresco: true);
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Tarjeta Principal de Balance Real
              BalanceCardWidget(
                deuda: deuda,
                onVerRecibo: onVerRecibo,
              ),
              const SizedBox(height: 16),

              // Aviso Preventivo de Corte (Dinámico según Informix)
              if (deuda != null && deuda.alertaCorte) ...[
                DisruptionNoticeCard(
                  fechaLimite: deuda.fechaProximoVencimiento,
                  mensajeAlerta: deuda.mensajeAlerta,
                ),
                const SizedBox(height: 16),
              ],
            ],

            // Canales de Atención
            const PaymentChannelsCard(),
          ],
        ),
      ),
    );
  }
}
