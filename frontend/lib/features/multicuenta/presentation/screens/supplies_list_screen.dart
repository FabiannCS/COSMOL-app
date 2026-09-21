import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../providers/multicuenta_provider.dart';

class SuppliesListScreen extends ConsumerWidget {
  const SuppliesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multicuentaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Suministros'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contratos Vinculados',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 6),
              Text(
                'Administra todos los contratos de agua asociados a tu cuenta digital.',
                style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
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
                          'No tienes suministros vinculados',
                          style: AppTextStyles.subtitle1,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega tu primer contrato para comenzar.',
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
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.borderSubtle,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowColor,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                                      item.alias.isNotEmpty
                                          ? item.alias
                                          : 'Suministro ${item.codSocio}',
                                      style: AppTextStyles.h3,
                                    ),
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
                                      isTitular
                                          ? 'MODO TITULAR'
                                          : 'CONSULTA Y PAGO',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.pin_outlined,
                                      size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
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
                                          'Suministro Activo',
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
                                      },
                                      child: const Text('Establecer como activo'),
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
                text: 'Vincular Nuevo Suministro',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/suministros/vincular'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
