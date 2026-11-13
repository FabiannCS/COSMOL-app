import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../deuda/presentation/providers/deuda_provider.dart';
import '../../../deuda/presentation/widgets/pago_qr_mock_sheet.dart';
import '../../data/models/notificacion_item_model.dart';
import '../providers/notificaciones_provider.dart';

class NotificacionesSheet extends ConsumerWidget {
  final VoidCallback? onPagar;
  final VoidCallback? onVerReconexion;
  final VoidCallback? onVerSocios;

  const NotificacionesSheet({
    super.key,
    this.onPagar,
    this.onVerReconexion,
    this.onVerSocios,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onPagar,
    VoidCallback? onVerReconexion,
    VoidCallback? onVerSocios,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificacionesSheet(
        onPagar: onPagar,
        onVerReconexion: onVerReconexion,
        onVerSocios: onVerSocios,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificacionesProvider);
    final notificaciones = notifState.notificaciones;
    final unreadCount = notifState.unreadCount;

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.78;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Barra de arrastre superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabecera de la Tarjeta Flotante
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Notificaciones',
                    style: AppTextStyles.subtitle1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.errorRed.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (unreadCount > 0)
                    IconButton(
                      tooltip: 'Marcar leídas',
                      icon: const Icon(
                        Icons.done_all_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        ref
                            .read(notificacionesProvider.notifier)
                            .marcarTodasComoLeidas();
                      },
                    ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSubtle),

            // Cuerpo: Lista de Notificaciones o Estado Vacío
            Expanded(
              child: notificaciones.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: notificaciones.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = notificaciones[index];
                        return _NotificacionCard(
                          item: notif,
                          onTap: () {
                            ref
                                .read(notificacionesProvider.notifier)
                                .marcarComoLeida(notif.id);
                          },
                          onAccion: () => _ejecutarAccion(context, ref, notif),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Todo en orden',
              style: AppTextStyles.subtitle1.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No tienes avisos urgentes ni facturas pendientes en este momento.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ejecutarAccion(
    BuildContext context,
    WidgetRef ref,
    NotificacionItemModel notif,
  ) {
    // 1. Marcar como leída
    ref.read(notificacionesProvider.notifier).marcarComoLeida(notif.id);

    // 2. Cerrar el modal sheet
    Navigator.of(context).pop();

    // 3. Ejecutar la acción correspondiente
    switch (notif.accionTipo) {
      case NotificacionAccionTipo.pagar:
        if (onPagar != null) {
          onPagar!();
        } else {
          final deudaState = ref.read(deudaProvider);
          final resumen = deudaState.resumenDeuda;
          if (resumen != null) {
            PagoQrMockSheet.show(
              context,
              codSocio: resumen.codSocio,
              nombreTitular: resumen.suministro?.nombreTitular ?? 'Socio COSMOL',
              montoBs: resumen.saldoPendienteBs,
              cantFacturas: resumen.cantidadFacturasPendientes,
              facturas: resumen.facturasPendientes,
            );
          }
        }
        break;

      case NotificacionAccionTipo.verReconexion:
        if (onVerReconexion != null) {
          onVerReconexion!();
        }
        break;

      case NotificacionAccionTipo.cambiarSuministro:
        if (onVerSocios != null) {
          onVerSocios!();
        }
        break;

      case NotificacionAccionTipo.ninguno:
        break;
    }
  }
}

class _NotificacionCard extends StatelessWidget {
  final NotificacionItemModel item;
  final VoidCallback onTap;
  final VoidCallback onAccion;

  const _NotificacionCard({
    required this.item,
    required this.onTap,
    required this.onAccion,
  });

  Color _getAccentColor() {
    switch (item.tipo) {
      case TipoNotificacion.avisoCorte:
        return AppColors.errorRed;
      case TipoNotificacion.facturaVencida:
        return AppColors.warningOrange;
      case TipoNotificacion.facturaImpaga:
        return AppColors.primary;
      case TipoNotificacion.reconexion:
        return const Color(0xFF6366F1); // Indigo
      case TipoNotificacion.multicuenta:
        return const Color(0xFF8B5CF6); // Violeta
      case TipoNotificacion.alDia:
        return AppColors.successGreen;
      case TipoNotificacion.avisoGeneral:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (item.tipo) {
      case TipoNotificacion.avisoCorte:
        return Icons.warning_amber_rounded;
      case TipoNotificacion.facturaVencida:
        return Icons.event_busy_rounded;
      case TipoNotificacion.facturaImpaga:
        return Icons.receipt_long_rounded;
      case TipoNotificacion.reconexion:
        return Icons.build_circle_outlined;
      case TipoNotificacion.multicuenta:
        return Icons.layers_outlined;
      case TipoNotificacion.alDia:
        return Icons.check_circle_outline_rounded;
      case TipoNotificacion.avisoGeneral:
        return Icons.info_outline_rounded;
    }
  }

  String _getAccionLabel() {
    switch (item.accionTipo) {
      case NotificacionAccionTipo.pagar:
        return 'Pagar con QR';
      case NotificacionAccionTipo.verReconexion:
        return 'Ver Trámite';
      case NotificacionAccionTipo.cambiarSuministro:
        return 'Ver Socios';
      case NotificacionAccionTipo.ninguno:
        return '';
    }
  }

  IconData _getAccionIcon() {
    switch (item.accionTipo) {
      case NotificacionAccionTipo.pagar:
        return Icons.qr_code_2_rounded;
      case NotificacionAccionTipo.verReconexion:
        return Icons.arrow_forward_rounded;
      case NotificacionAccionTipo.cambiarSuministro:
        return Icons.swap_horiz_rounded;
      case NotificacionAccionTipo.ninguno:
        return Icons.arrow_forward_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor();
    final icon = _getIcon();
    final hasAction = item.accionTipo != NotificacionAccionTipo.ninguno;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: item.esLeida ? AppColors.lightBackground : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.esLeida
                ? AppColors.borderSubtle
                : accentColor.withAlpha(60),
            width: item.esLeida ? 1 : 1.2,
          ),
          boxShadow: [
            if (!item.esLeida)
              BoxShadow(
                color: accentColor.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra vertical de acento de color
              Container(
                width: 4.5,
                color: accentColor,
              ),

              // Contenido principal de la tarjeta
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icono temático en caja circular
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accentColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: accentColor, size: 20),
                          ),
                          const SizedBox(width: 10),

                          // Título y punto azul de no leído
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.titulo,
                                        style: AppTextStyles.subtitle2.copyWith(
                                          fontWeight: item.esLeida
                                              ? FontWeight.w600
                                              : FontWeight.bold,
                                          color: item.esLeida
                                              ? AppColors.textPrimary
                                              : AppColors.darkNavy,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (!item.esLeida) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Alerta de servicio',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Mensaje explicativo
                      Text(
                        item.mensaje,
                        style: AppTextStyles.body2.copyWith(
                          color: item.esLeida
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),

                      // Botón de acción embebido (si aplica)
                      if (hasAction) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: onAccion,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accentColor.withAlpha(70),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getAccionIcon(),
                                    size: 15,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getAccionLabel(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
