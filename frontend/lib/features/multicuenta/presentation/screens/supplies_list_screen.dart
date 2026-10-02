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
          '¿Estás seguro de que deseas desvincular el socio "${item.alias.isNotEmpty ? item.alias : item.codSocio}" (Cód: ${item.codSocio})?\n\nDejarás de ver este suministro en tu lista.',
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
                        'Socio ${item.alias.isNotEmpty ? item.alias : item.codSocio} desvinculado con éxito.',
                      ),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ref.read(multicuentaProvider).errorMessage ??
                            'Error al desvincular socio.',
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

  String _getAliasDisplay(SuministroModel item) {
    final isTitular = item.rol.toUpperCase() == 'TITULAR';

    // Para modo consulta (CONSULTA_PAGO / Inquilino):
    // Mostrar la inicial de cada palabra y lo demás con ****** para evitar redundancia y proteger datos
    if (!isTitular) {
      if (item.nombre != null && item.nombre!.trim().isNotEmpty) {
        return _enmascararNombre(item.nombre!);
      }

      final alias = item.alias.trim();
      final aliasLower = alias.toLowerCase();

      if (alias.isEmpty ||
          alias == 'Mi Casa' ||
          alias == 'Mi casa' ||
          alias == 'Mi Suministro' ||
          alias == 'Casa Principal' ||
          alias == 'Socio de Titular' ||
          alias == 'Socio de Titularidad' ||
          alias == 'Suministro Consulta' ||
          alias == 'Socio de Consulta' ||
          alias == 'Socio de Consulta y Pago' ||
          alias == 'Cuenta de Consulta' ||
          aliasLower.contains('suministro consulta') ||
          aliasLower.contains('socio de consulta')) {
        return 'Socio: ${item.codSocio}';
      }
      return alias;
    }

    // Para modo TITULAR sí se puede mostrar el nombre completo o el alias
    if (item.nombre != null && item.nombre!.trim().isNotEmpty) {
      return item.nombre!.trim();
    }

    final alias = item.alias.trim();

    if (alias.isEmpty ||
        alias == 'Mi Casa' ||
        alias == 'Mi casa' ||
        alias == 'Mi Suministro' ||
        alias == 'Casa Principal' ||
        alias == 'Socio de Titular' ||
        alias == 'Socio de Titularidad' ||
        alias == 'Suministro Consulta' ||
        alias == 'Socio de Consulta' ||
        alias == 'Socio de Consulta y Pago' ||
        alias == 'Cuenta de Consulta' ||
        alias.toLowerCase().contains('suministro consulta') ||
        alias.toLowerCase().contains('socio de consulta')) {
      return 'Socio: ${item.codSocio}';
    }

    return alias;
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
            'Socios Vinculados',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          Text(
            'Administra diferentes socios vinculados a tu cuenta.',
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
                      'No tienes algún socio vinculado',
                      style: AppTextStyles.subtitle1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agrega tu primer socio para comenzar.',
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
                    final isTitular = item.rol.toUpperCase() == 'TITULAR';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.borderSubtle,
                          width: isSelected ? 2 : 1,
                        ),
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
                                isTitular
                                    ? 'TITULAR'
                                    : 'CONSULTA',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                                        color: AppColors.successGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Socio Activo',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.successGreen,
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
                              if (!isTitular)
                                TextButton.icon(
                                  onPressed: () => _confirmarDesvinculacion(
                                      context, ref, item),
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
