import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../deuda/data/models/deuda_response_model.dart';

/// Tarjeta principal de balance conectada a datos reales de COSMOL.
class BalanceCardWidget extends StatelessWidget {
  final ResumenDeudaModel? deuda;
  final VoidCallback onVerRecibo;

  const BalanceCardWidget({
    super.key,
    required this.deuda,
    required this.onVerRecibo,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = deuda?.hasDebt ?? false;

    if (hasDebt && deuda != null) {
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
                          'Bs',
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.darkNavy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          deuda!.saldoFormateado,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${deuda!.cantidadFacturasPendientes} ${deuda!.cantidadFacturasPendientes == 1 ? "factura pendiente" : "facturas pendientes"}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Botón Pagar Ahora con QR
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Módulo de Pago con QR (Pasarelas externas) estará disponible en la Fase 2.',
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_rounded, size: 20),
                label: const Text(
                  'Pagar Ahora',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            if (facturas.isNotEmpty) ...[
              const SizedBox(height: 16),
              // Desglose de facturas impagas reales
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < facturas.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: AppColors.borderSubtle),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                facturas[i].mesLectura.isNotEmpty
                                    ? facturas[i].mesLectura
                                    : facturas[i].periodo,
                                style: AppTextStyles.subtitle2.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (facturas[i].nroFactura.isNotEmpty)
                                Text(
                                  'Fac. N° ${facturas[i].nroFactura}',
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
                                facturas[i].montoFormateado,
                                style: AppTextStyles.subtitle2.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                facturas[i].estaVencida ? 'Vencida' : 'Impaga',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.errorRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Estado Al Día
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: AppColors.successGreen),
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
            label: const Text('Ver Último Recibo Pagado'),
          ),
        ],
      ),
    );
  }
}
