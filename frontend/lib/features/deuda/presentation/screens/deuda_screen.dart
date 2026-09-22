import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../providers/deuda_provider.dart';
import '../widgets/balance_card_widget.dart';
import '../widgets/disruption_notice_card.dart';
import '../widgets/payment_channels_card.dart';

/// Pantalla principal de Consulta de Deuda e Inicio del Dashboard conectada al backend FastAPI.
class DeudaScreen extends ConsumerStatefulWidget {
  final dynamic activeSuministro;
  final VoidCallback onVerRecibo;

  const DeudaScreen({
    super.key,
    required this.activeSuministro,
    required this.onVerRecibo,
  });

  @override
  ConsumerState<DeudaScreen> createState() => _DeudaScreenState();
}

class _DeudaScreenState extends ConsumerState<DeudaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final codSocio = widget.activeSuministro?.codSocio?.toString().trim();
      if (codSocio != null && codSocio.isNotEmpty) {
        ref.read(deudaProvider.notifier).cargarDeuda(codSocio);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DeudaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCod = oldWidget.activeSuministro?.codSocio?.toString().trim();
    final newCod = widget.activeSuministro?.codSocio?.toString().trim();
    if (newCod != null && newCod.isNotEmpty && newCod != oldCod) {
      ref.read(deudaProvider.notifier).cargarDeuda(newCod);
    }
  }

  String _getMesActual() {
    const meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final now = DateTime.now();
    final mes = meses[now.month - 1];
    return '$mes ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final codSocio = widget.activeSuministro?.codSocio?.toString().trim() ?? '';
    final deudaState = ref.watch(deudaProvider);

    return RefreshIndicator(
      onRefresh: () async {
        if (codSocio.isNotEmpty) {
          await ref
              .read(deudaProvider.notifier)
              .cargarDeuda(codSocio, forzarRefresco: true);
        }
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
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      if (deudaState.resumenDeuda?.origenDatos == 'CACHE') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.bolt, size: 12, color: AppColors.primary),
                              SizedBox(width: 2),
                              Text(
                                'Caché',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _getMesActual(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Estado de carga inicial
            if (deudaState.isLoading && deudaState.resumenDeuda == null)
              Container(
                height: 180,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 3),
                      SizedBox(height: 16),
                      Text(
                        'Consultando saldo en tiempo real con COSMOL...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // Estado de error
            else if (deudaState.errorMessage != null &&
                deudaState.resumenDeuda == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.errorRed, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      deudaState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (codSocio.isNotEmpty) {
                          ref
                              .read(deudaProvider.notifier)
                              .cargarDeuda(codSocio, forzarRefresco: true);
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reintentar Consulta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            // Estado con datos reales del backend
            else ...[
              // Tarjeta Principal de Balance
              BalanceCardWidget(
                deuda: deudaState.resumenDeuda,
                onVerRecibo: widget.onVerRecibo,
              ),
              const SizedBox(height: 16),

              // Aviso Preventivo de Corte (Si aplica por tener 2 o más facturas impagas)
              if (deudaState.alertaCorte) ...[
                DisruptionNoticeCard(deuda: deudaState.resumenDeuda),
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
