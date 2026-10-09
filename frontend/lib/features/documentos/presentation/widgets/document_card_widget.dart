import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../data/models/documento_model.dart';

/// Fila expandible y estilizada para visualizar documentos y facturas de COSMOL R.L.
///
/// Estado colapsado: Muestra periodo, identificador, monto, badge de estado y chevron.
/// Estado expandido: Revela fechas clave y los botones de acción ("Ver PDF", "Descargar", "Compartir").
class DocumentCardWidget extends StatefulWidget {
  final DocumentoModel documento;
  final bool isDownloading;
  final VoidCallback onVer;
  final VoidCallback onDescargar;
  final VoidCallback onCompartir;
  final bool initiallyExpanded;

  const DocumentCardWidget({
    super.key,
    required this.documento,
    this.isDownloading = false,
    required this.onVer,
    required this.onDescargar,
    required this.onCompartir,
    this.initiallyExpanded = false,
  });

  @override
  State<DocumentCardWidget> createState() => _DocumentCardWidgetState();
}

class _DocumentCardWidgetState extends State<DocumentCardWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documento;
    final isPagado = doc.isPagado;
    final isCorte = doc.isAvisoCorte;

    // Configuración visual del badge según estado y tipo
    final Color badgeBg;
    final Color badgeText;
    final String badgeLabel;

    if (isCorte) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = AppColors.errorRed;
      badgeLabel = 'Corte';
    } else if (isPagado) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
      badgeLabel = 'Pagada';
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFB45309);
      badgeLabel = 'Pendiente';
    }

    // Título y subtítulo limpios
    final String tituloPrincipal = doc.isFactura
        ? doc.periodoFormateado
        : doc.tituloLegible;

    final String subtitulo;
    if (doc.isFactura && doc.nroFactura != null && doc.nroFactura!.isNotEmpty) {
      subtitulo = 'Factura #${doc.nroFactura}';
    } else if (doc.isAvisoCobranza && doc.nroFacip != null && doc.nroFacip!.isNotEmpty) {
      subtitulo = doc.periodoFormateado;
    } else {
      subtitulo = doc.periodoFormateado;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isExpanded
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isCorte ? const Color(0xFFFECACA) : AppColors.borderSubtle),
          width: _isExpanded ? 1.3 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isExpanded ? 0.04 : 0.015),
            blurRadius: _isExpanded ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header principal interactivo (siempre visible)
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Columna izquierda: Título y subtítulo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tituloPrincipal,
                          style: AppTextStyles.subtitle2.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitulo,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Columna derecha: Monto y Badge de estado con Chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        doc.montoBsFormateado,
                        style: AppTextStyles.subtitle2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCorte ? AppColors.errorRed : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Contenido desplegable animado
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(doc),
            crossFadeState:
                _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(DocumentoModel doc) {
    final isPagado = doc.isPagado;

    return Column(
      children: [
        const Divider(height: 1, color: AppColors.borderSubtle),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila de metadatos de fechas (concisa y limpia)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Emisión: ${doc.fechaEmisionFormateada}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (isPagado && doc.fechaPagoFormateada.isNotEmpty)
                    Text(
                      'Pagado: ${doc.fechaPagoFormateada}',
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    )
                  else if (doc.fechaVencimiento != null)
                    Text(
                      'Vence: ${doc.fechaVencimientoFormateada}',
                      style: AppTextStyles.caption.copyWith(
                        color: doc.isPendiente &&
                                doc.fechaVencimiento!.isBefore(DateTime.now())
                            ? AppColors.errorRed
                            : AppColors.textSecondary,
                        fontWeight: doc.isPendiente &&
                                doc.fechaVencimiento!.isBefore(DateTime.now())
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Fila de acciones principales
              if (doc.permiteDescarga)
                Row(
                  children: [
                    // Botón principal: Ver PDF
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.isDownloading ? null : widget.onVer,
                        label: const Text('Ver PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón: Descargar
                    OutlinedButton.icon(
                      onPressed: widget.isDownloading ? null : widget.onDescargar,
                      icon: widget.isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Descargar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderSubtle),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Botón: Compartir
                    IconButton(
                      onPressed: widget.isDownloading ? null : widget.onCompartir,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      tooltip: 'Compartir',
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.borderSubtle),
                        ),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  child: Text(
                    'Registro histórico de pago',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
