import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../data/models/resumen_deuda_model.dart';
import '../providers/deuda_provider.dart';
import 'pago_qr_mock_sheet.dart';

/// Tarjeta principal de balance conectada a datos en tiempo real del backend (COSMOL R.L.).
class BalanceCardWidget extends ConsumerWidget {
  final ResumenDeudaModel? deuda;
  final VoidCallback onVerRecibo;

  const BalanceCardWidget({
    super.key,
    required this.deuda,
    required this.onVerRecibo,
  });

  void _showPaymentModal(BuildContext context, WidgetRef ref) {
    final deudaState = ref.read(deudaProvider);
    if (deudaState.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El pago en línea requiere conexión a internet activa.',
          ),
          backgroundColor: AppColors.warningOrange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final codSocio = deuda?.codSocio ?? '';
    final montoTotal = deuda?.saldoPendienteBs ?? 0.0;
    final titular = deuda?.suministro?.nombreTitular ?? 'Socio COSMOL';
    final cantFacturas = deuda?.cantidadFacturasPendientes ?? 1;

    PagoQrMockSheet.show(
      context,
      codSocio: codSocio,
      nombreTitular: titular,
      montoBs: montoTotal,
      cantFacturas: cantFacturas,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = deuda != null &&
        (deuda!.saldoPendienteBs > 0 || deuda!.cantidadFacturasPendientes > 0);

    if (hasDebt) {
      final facturas = deuda!.facturasPendientes;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL A PAGAR',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          deuda!.moneda,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.darkNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deuda!.saldoPendienteBs.toStringAsFixed(2),
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 32,
                            color: AppColors.darkNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Botón Pagar Ahora con Selector de Pasarelas Oficiales
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _showPaymentModal(context, ref),
                icon: const Icon(Icons.payment_rounded, size: 20),
                label: const Text(
                  'Pagar Ahora',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Desglose dinámico de facturas impagas reales
            if (facturas.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: List.generate(facturas.length, (index) {
                    final f = facturas[index];
                    final isLast = index == facturas.length - 1;

                    final mesNombre = f.mesLectura.isNotEmpty
                        ? f.mesLectura
                        : 'Periodo ${f.periodo}';

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mesNombre,
                                  style: AppTextStyles.subtitle2.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (f.nroFactura.isNotEmpty)
                                  Text(
                                    'Factura #${f.nroFactura}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Bs ${f.montoBs.toStringAsFixed(2)}',
                                      style: AppTextStyles.subtitle2.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      f.estaVencida ? 'Vencida' : 'Impaga',
                                      style: AppTextStyles.caption.copyWith(
                                        color: f.estaVencida
                                            ? AppColors.errorRed
                                            : const Color(0xFFE65100),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        if (!isLast)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child:
                                Divider(height: 1, color: AppColors.borderSubtle),
                          ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        ),
      );
    }

    // Estado Al Día (saldo 0 Bs)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL A PAGAR',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Bs 0.00',
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified,
                        size: 16, color: AppColors.successGreen),
                    SizedBox(width: 4),
                    Text(
                      'Al día con tus pagos',
                      style: TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onVerRecibo,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('Ver Historial de Facturas'),
          ),
        ],
      ),
    );
  }
}
