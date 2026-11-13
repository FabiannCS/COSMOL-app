import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../auth/data/models/login_response_model.dart';
import '../providers/multicuenta_provider.dart';

/// Pantalla y Tab unificado para Gestión de Suministros Multicuenta.
class SuppliesListScreen extends ConsumerWidget {
  final bool isEmbedded;
  final VoidCallback? onSuministroSeleccionado;

  const SuppliesListScreen({
    super.key,
    this.isEmbedded = false,
    this.onSuministroSeleccionado,
  });

  void _mostrarAvisoNoDesvincularPrincipal(
    BuildContext context,
    SuministroModel item,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.cardSurface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Socio Principal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'El socio "${item.alias.isNotEmpty ? item.alias : item.codSocio}" (Cód: ${item.codSocio}) es la cuenta principal registrada con la que creaste tu acceso en COSMOL R.L.\n\nPor seguridad del sistema, no es posible desvincular la cuenta principal registrada.',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _confirmarDesvinculacion(
    BuildContext context,
    WidgetRef ref,
    SuministroModel item,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.cardSurface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_off_rounded,
                color: AppColors.errorRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Desvincular Socio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas desvincular la cuenta "${item.alias.isNotEmpty ? item.alias : item.codSocio}" (Cód: ${item.codSocio})?\n\nDejarás de ver esta cuenta en tu lista.',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final success = await ref
                  .read(multicuentaProvider.notifier)
                  .desvincularSuministro(item.codSocio);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cuenta ${item.alias.isNotEmpty ? item.alias : item.codSocio} desvinculada con éxito.',
                      ),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                  // Si se desvinculó la cuenta activa en modo consulta, redirigir al titular principal
                  if (item.isInquilino) {
                    onSuministroSeleccionado?.call();
                    context.go('/dashboard');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ref.read(multicuentaProvider).errorMessage ??
                            'Error al desvincular cuenta.',
                      ),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
  }

  String _enmascararNombre(String nombreCompleto) {
    final limpio = nombreCompleto.trim();
    if (limpio.isEmpty) return '';

    final palabras = limpio.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return '';

    return palabras.map((p) {
      if (p.length <= 1) return p;
      return '${p[0]}***';
    }).join(' ');
  }

  bool _hasCustomAlias(String alias, String codSocio) {
    final clean = alias.trim();
    if (clean.isEmpty) return false;
    final cleanLower = clean.toLowerCase();

    if (clean == 'Socio: $codSocio' ||
        clean == 'Socio $codSocio' ||
        clean == 'Suministro $codSocio' ||
        clean == 'Suministro: $codSocio' ||
        clean == 'Mi Casa' ||
        clean == 'Mi casa' ||
        clean == 'Mi Suministro' ||
        clean == 'Casa Principal' ||
        clean == 'Socio de Titular' ||
        clean == 'Socio de Titularidad' ||
        clean == 'Suministro Consulta' ||
        clean == 'Socio de Consulta' ||
        clean == 'Socio de Consulta y Pago' ||
        clean == 'Cuenta de Consulta' ||
        cleanLower.startsWith('suministro consulta') ||
        cleanLower.startsWith('socio de consulta') ||
        cleanLower.startsWith('socio: ') ||
        cleanLower.startsWith('suministro: ')) {
      return false;
    }
    return true;
  }

  String _getAliasDisplay(SuministroModel item) {
    final isTitular = item.rol.toUpperCase() == 'TITULAR';

    // Para modo consulta (CONSULTA_PAGO / Inquilino):
    // Mostrar la inicial de cada palabra y asteriscos para proteger datos
    if (!isTitular) {
      if (item.nombre != null && item.nombre!.trim().isNotEmpty) {
        return _enmascararNombre(item.nombre!);
      }
      return 'Socio: ${item.codSocio}';
    }

    // Para modo TITULAR: mostrar el nombre completo del titular
    if (item.nombre != null && item.nombre!.trim().isNotEmpty) {
      return item.nombre!.trim();
    }

    return 'Socio: ${item.codSocio}';
  }

  String _getBadgeLabel(SuministroModel item) {
    if (item.esSuministroPrincipal) {
      return 'TITULAR PRINCIPAL';
    }
    if (item.rol.toUpperCase() == 'TITULAR') {
      return 'TITULAR SECUNDARIO';
    }
    return 'CONSULTA Y PAGO';
  }

  Color _getBadgeColor(SuministroModel item) {
    if (item.esSuministroPrincipal) {
      return AppColors.primary;
    }
    if (item.rol.toUpperCase() == 'TITULAR') {
      return const Color(0xFF1D4ED8);
    }
    return AppColors.warningOrange;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multicuentaProvider);

    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuentas Vinculadas',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Administra las diferentes cuentas asociadas a tu usuario.',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (state.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.suministros.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop_outlined,
                        size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes alguna cuenta vinculada',
                      style: AppTextStyles.subtitle1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agrega tu primera cuenta para comenzar.',
                      style: AppTextStyles.body2
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(multicuentaProvider.notifier).cargarSuministros(),
                child: ListView.separated(
                  itemCount: state.suministros.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = state.suministros[index];
                    final isSelected =
                        item.codSocio == state.activeSuministro?.codSocio;
                    final isModoConsultaActivo =
                        state.activeSuministro?.isInquilino ?? false;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.surfaceContainerLow
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withAlpha(20),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          else
                            const BoxShadow(
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
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _getAliasDisplay(item),
                                  style: AppTextStyles.h3,
                                ),
                              ),
                              Text(
                                _getBadgeLabel(item),
                                style: TextStyle(
                                  color: _getBadgeColor(item),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          if (_hasCustomAlias(item.alias, item.codSocio)) ...[
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                style: AppTextStyles.body2.copyWith(
                                  color: AppColors.primary,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Alias: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  TextSpan(
                                    text: item.alias.trim(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Código de Socio: ${item.codSocio}',
                                style: AppTextStyles.body2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              if (isSelected)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 16,
                                        color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cuenta Activa',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                TextButton(
                                  onPressed: () {
                                    ref
                                        .read(multicuentaProvider.notifier)
                                        .seleccionarSuministro(item);
                                    onSuministroSeleccionado?.call();
                                  },
                                  child: const Text('Activar'),
                                ),
                              if (!isModoConsultaActivo || isSelected)
                                TextButton.icon(
                                  onPressed: () {
                                    if (item.esSuministroPrincipal) {
                                      _mostrarAvisoNoDesvincularPrincipal(
                                          context, item);
                                    } else {
                                      _confirmarDesvinculacion(
                                          context, ref, item);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.link_off_rounded,
                                    size: 16,
                                    color: AppColors.errorRed,
                                  ),
                                  label: const Text(
                                    'Desvincular',
                                    style: TextStyle(
                                      color: AppColors.errorRed,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.errorRed,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          CosmolButton(
            text: 'Vincular Nuevo Socio',
            icon: Icons.add_rounded,
            onPressed: () => context.push('/suministros/vincular'),
          ),
        ],
      ),
    );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: CosmolAppBar(
        title: 'COSMOL R.L.',
        subtitle: 'Mis Cuentas Vinculadas',
        showBackButton: true,
        onBackPressed: () => context.pop(),
      ),
      body: SafeArea(child: content),
    );
  }
}
