import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../data/models/resumen_deuda_model.dart';
import '../providers/deuda_provider.dart';
import '../providers/pagos_provider.dart';
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
    final facturas = deuda?.facturasPendientes ?? const [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra superior indicadora de arrastre
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modalidad de Pago',
                              style: AppTextStyles.subtitle1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total adeudado: Bs ${montoTotal.toStringAsFixed(2)} ($cantFacturas ${cantFacturas == 1 ? 'factura' : 'facturas'})',
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
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Selecciona cómo deseas realizar tu pago:',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Opción 1: Pagar por la App (flujo QR Jesús Nazareno + FIFO)
                  _buildOpcionPagoCard(
                    context: context,
                    titulo: 'Pagar por la App',
                    subtitulo: 'Código QR Simple (Jesús Nazareno) y selección cronológica de facturas dentro de la app',
                    badge: 'Recomendado',
                    badgeColor: const Color(0xFF006837),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: Color(0xFF006837),
                        size: 28,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      PagoQrMockSheet.show(
                        context,
                        codSocio: codSocio,
                        nombreTitular: titular,
                        montoBs: montoTotal,
                        cantFacturas: cantFacturas,
                        facturas: facturas,
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Opción 2: Multipago Bolivia (Redirección Externa a web oficial)
                  _buildOpcionPagoCard(
                    context: context,
                    titulo: 'Multipago Bolivia',
                    subtitulo: 'Paga en la pasarela web oficial con tarjeta de débito/crédito o banca por internet',
                    badge: 'Web Externa',
                    badgeColor: const Color(0xFF0288D1),
                    leading: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/images/multipago.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.open_in_browser_rounded,
                            color: Color(0xFF0288D1),
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _redireccionarMultipago(context, ref, codSocio);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpcionPagoCard({
    required BuildContext context,
    required String titulo,
    required String subtitulo,
    required String badge,
    required Color badgeColor,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titulo,
                          style: AppTextStyles.subtitle2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _redireccionarMultipago(
    BuildContext context,
    WidgetRef ref,
    String codSocio,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Conectando con Multipago Bolivia...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final url = await ref
          .read(pagosProvider.notifier)
          .registrarIntentoYObtenerUrl(
            codSocio: codSocio,
            canalId: 'multipago',
          );

      final urlFinal = (url != null && url.isNotEmpty)
          ? url
          : 'https://multipago.com/service/cosmol_payment/first';

      final Uri uri = Uri.parse(urlFinal);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      if (context.mounted && codSocio.isNotEmpty) {
        ref.read(deudaProvider.notifier).cargarDeuda(codSocio, forzarRefresco: true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir Multipago: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = deuda != null &&
        (deuda!.saldoPendienteBs > 0 || deuda!.cantidadFacturasPendientes > 0);

    if (hasDebt) {
      // Orden descendente en la vista de Deuda (factura más reciente primero)
      // sin alterar el orden FIFO interno que utiliza el modal de pagos.
      final facturas = List<FacturaPendienteModel>.from(deuda!.facturasPendientes)
        ..sort((a, b) {
          final cmpAnio = b.anio.compareTo(a.anio);
          if (cmpAnio != 0) return cmpAnio;
          final cmpMes = b.mes.compareTo(a.mes);
          if (cmpMes != 0) return cmpMes;
          return a.diasMora.compareTo(b.diasMora);
        });

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
                    final estado = facturas.obtenerEstadoFactura(f);
                    final isLast = index == facturas.length - 1;

                    final mesNombre = f.mesLectura.isNotEmpty
                        ? f.mesLectura
                        : 'Periodo ${f.periodo}';

                    final String estadoLabel;
                    final Color estadoColor;
                    switch (estado) {
                      case EstadoFacturaDeuda.pagada:
                        estadoLabel = 'Pagada';
                        estadoColor = AppColors.successGreen;
                        break;
                      case EstadoFacturaDeuda.impaga:
                        estadoLabel = 'Impaga';
                        estadoColor = const Color(0xFFE65100);
                        break;
                      case EstadoFacturaDeuda.vencida:
                        estadoLabel = 'Vencida';
                        estadoColor = AppColors.errorRed;
                        break;
                    }

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
                                      estadoLabel,
                                      style: AppTextStyles.caption.copyWith(
                                        color: estadoColor,
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
          if (deuda?.suministro?.rolUsuario == 'TITULAR') ...[
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
        ],
      ),
    );
  }
}
