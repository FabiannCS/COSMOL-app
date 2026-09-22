import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../data/models/documento_model.dart';

/// Tarjeta de visualización y acciones para un documento oficial de COSMOL R.L.
class DocumentCardWidget extends StatelessWidget {
  final DocumentoModel documento;
  final bool isDownloading;
  final VoidCallback onVer;
  final VoidCallback onDescargar;
  final VoidCallback onCompartir;

  const DocumentCardWidget({
    super.key,
    required this.documento,
    this.isDownloading = false,
    required this.onVer,
    required this.onDescargar,
    required this.onCompartir,
  });

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    Color typeBgColor;
    IconData typeIcon;

    if (documento.isFactura) {
      typeColor = const Color(0xFF1E40AF); // Blue
      typeBgColor = const Color(0xFFEFF6FF);
      typeIcon = Icons.receipt_long_rounded;
    } else if (documento.isAvisoCobranza) {
      typeColor = const Color(0xFF0E7490); // Teal / Cyan
      typeBgColor = const Color(0xFFECFEFF);
      typeIcon = Icons.description_outlined;
    } else {
      typeColor = const Color(0xFFDC2626); // Red / Orange
      typeBgColor = const Color(0xFFFEF2F2);
      typeIcon = Icons.warning_amber_rounded;
    }

    final isPagado = documento.isPagado;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: documento.isAvisoCorte
              ? const Color(0xFFFECACA)
              : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la tarjeta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        typeIcon,
                        color: typeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              documento.tituloLegible,
                              style: AppTextStyles.subtitle1.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge de estado de pago
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            child: Text(
                              isPagado ? 'PAGADO' : 'PENDIENTE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPagado
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 14),

                // Metadatos: Periodo, Monto, Fechas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periodo',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          documento.periodoFormateado,
                          style: AppTextStyles.body2.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Monto Total',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          documento.montoBsFormateado,
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emisión: ${documento.fechaEmisionFormateada}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (documento.fechaVencimiento != null)
                      Text(
                        'Vence: ${documento.fechaVencimientoFormateada}',
                        style: AppTextStyles.caption.copyWith(
                          color: !isPagado &&
                                  documento.fechaVencimiento!
                                      .isBefore(DateTime.now())
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: !isPagado &&
                                  documento.fechaVencimiento!
                                      .isBefore(DateTime.now())
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Barra de acciones inferiores
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: const Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Botón Ver PDF
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: isDownloading ? null : onVer,
                    label: const Text('Ver PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Descargar
                IconButton(
                  onPressed: isDownloading ? null : onDescargar,
                  icon: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          color: AppColors.primary,
                        ),
                  tooltip: 'Guardar en el dispositivo',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.cardSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Botón Compartir
                IconButton(
                  onPressed: isDownloading ? null : onCompartir,
                  icon: const Icon(
                    Icons.share_outlined,
                    color: AppColors.primary, // Green
                  ),
                  tooltip: 'Compartir vía WhatsApp',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.cardSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
