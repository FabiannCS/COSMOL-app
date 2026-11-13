import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../providers/notificaciones_provider.dart';
import 'notificaciones_sheet.dart';

class NotificacionesBellIcon extends ConsumerWidget {
  final VoidCallback? onPagar;
  final VoidCallback? onVerReconexion;
  final VoidCallback? onVerSocios;

  const NotificacionesBellIcon({
    super.key,
    this.onPagar,
    this.onVerReconexion,
    this.onVerSocios,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificacionesProvider);
    final unreadCount = notifState.unreadCount;

    return IconButton(
      tooltip: 'Notificaciones',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: AppColors.onSurfaceVariant,
            size: 24,
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.errorRed,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.pureWhite,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.errorRed.withAlpha(100),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: AppColors.pureWhite,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        NotificacionesSheet.show(
          context,
          onPagar: onPagar,
          onVerReconexion: onVerReconexion,
          onVerSocios: onVerSocios,
        );
      },
    );
  }
}

