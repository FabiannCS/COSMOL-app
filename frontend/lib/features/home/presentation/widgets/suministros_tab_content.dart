import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';

/// Contenido de la Pestaña 3: Gestión Multicuenta / Suministros.
class SuministrosTabContent extends ConsumerWidget {
  final dynamic multicuentaState;
  final VoidCallback onSuministroSeleccionado;

  const SuministrosTabContent({
    super.key,
    required this.multicuentaState,
    required this.onSuministroSeleccionado,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suministros = multicuentaState.suministros;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contratos Vinculados', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            'Administra todos tus contratos de agua asociados.',
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: suministros.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = suministros[index];
                final isSelected =
                    item.codSocio == multicuentaState.activeSuministro?.codSocio;
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.alias.isNotEmpty
                                ? item.alias
                                : 'Suministro ${item.codSocio}',
                            style: AppTextStyles.subtitle1
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isTitular
                                  ? AppColors.primary
                                  : AppColors.warningOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isTitular ? 'MODO TITULAR' : 'CONSULTA Y PAGO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Código de Socio: ${item.codSocio}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      if (isSelected)
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: AppColors.successGreen),
                            SizedBox(width: 4),
                            Text(
                              'Suministro Activo',
                              style: TextStyle(
                                color: AppColors.successGreen,
                                fontSize: 12,
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
                            onSuministroSeleccionado();
                          },
                          child: const Text('Establecer como activo'),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
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
              ),
              onPressed: () => context.push('/suministros/vincular'),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Vincular Nuevo Suministro',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
