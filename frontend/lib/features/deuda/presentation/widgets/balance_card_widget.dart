import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../data/models/resumen_deuda_model.dart';
import '../providers/deuda_provider.dart';
import '../providers/pagos_provider.dart';

/// Tarjeta principal de balance conectada a datos en tiempo real del backend (COSMOL R.L.).
class BalanceCardWidget extends ConsumerWidget {
  final ResumenDeudaModel? deuda;
  final VoidCallback onVerRecibo;

  const BalanceCardWidget({
    super.key,
    required this.deuda,
    required this.onVerRecibo,
  });

  Future<void> _launchPaymentUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // Fallback a modo plataforma estándar
        final fallbackLaunched = await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
        if (!fallbackLaunched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el navegador para completar el pago.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      // Intentar fallback directo en caso de excepción en modo externo
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al conectar con la pasarela de pago: $e'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    }
  }

  void _showPaymentModal(BuildContext context, WidgetRef ref) {
    final codSocio = deuda?.codSocio ?? '';
    final saldo = deuda?.saldoPendienteBs.toStringAsFixed(2) ?? '0.00';

    if (codSocio.isNotEmpty) {
      // Cargar catálogo dinámico oficial desde el backend
      ref.read(pagosProvider.notifier).cargarCanales(codSocio);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, refConsumer, _) {
            final pagosState = refConsumer.watch(pagosProvider);
            final deudaMonto = pagosState.canalesResponse != null
                ? pagosState.canalesResponse!.totalDeudaBs.toStringAsFixed(2)
                : saldo;

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra de arrastre superior
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Encabezado
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Canales de Pago Seguro',
                              style: AppTextStyles.h3.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total: Bs $deudaMonto',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Selecciona una plataforma autorizada de COSMOL R.L.:',
                    style: AppTextStyles.body2.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Estado de Carga
                  if (pagosState.isLoading && pagosState.canales.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(strokeWidth: 3),
                            SizedBox(height: 12),
                            Text(
                              'Consultando pasarelas oficiales...',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                  // Estado de Error
                  else if (pagosState.errorMessage != null && pagosState.canales.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            pagosState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.errorRed,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              refConsumer.read(pagosProvider.notifier).cargarCanales(codSocio);
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reintentar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // Catálogo Dinámico de Canales
                  else ...[
                    ...pagosState.canales.map((canal) {
                      final isStore = canal.icono == 'storefront';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: pagosState.isRegistering
                              ? null
                              : () async {
                                  // 1. Registrar intento en Backend para activar ventana de verificación en Redis
                                  final url = await refConsumer
                                      .read(pagosProvider.notifier)
                                      .registrarIntentoYObtenerUrl(
                                        codSocio: codSocio,
                                        canalId: canal.id,
                                      );

                                  if (context.mounted) {
                                    Navigator.of(ctx).pop();
                                  }

                                  // 2. Abrir pasarela oficial en navegador
                                  final urlFinal = (url != null && url.isNotEmpty)
                                      ? url
                                      : canal.urlRedireccion;

                                  if (context.mounted) {
                                    await _launchPaymentUrl(context, urlFinal);
                                  }

                                  // 3. Al volver de la pasarela, forzar refresco de deuda para Smart Polling
                                  if (codSocio.isNotEmpty) {
                                    refConsumer
                                        .read(deudaProvider.notifier)
                                        .cargarDeuda(codSocio, forzarRefresco: true);
                                  }
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderSubtle),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowColor,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE3F2FD),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isStore
                                        ? Icons.storefront_rounded
                                        : Icons.qr_code_2_rounded,
                                    color: const Color(0xFF0288D1),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            canal.nombre,
                                            style: AppTextStyles.subtitle1.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (canal.soportaQr) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'QR SIMPLE',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2E7D32),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        canal.descripcion,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),

                  // Aviso de Seguridad PCI / Transparencia
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'COSMOL R.L. no almacena datos de tarjetas ni contraseñas bancarias. Tu transacción se procesa de forma directa y segura en la pasarela seleccionada.',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
