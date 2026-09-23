import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_text_field.dart';
import '../providers/multicuenta_provider.dart';

class BindSupplyScreen extends ConsumerStatefulWidget {
  const BindSupplyScreen({super.key});

  @override
  ConsumerState<BindSupplyScreen> createState() => _BindSupplyScreenState();
}

class _BindSupplyScreenState extends ConsumerState<BindSupplyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers Modo Titular
  final _formKeyTitular = GlobalKey<FormState>();
  final _codSocioTitularController = TextEditingController();
  final _ciMedidorController = TextEditingController();
  final _aliasTitularController = TextEditingController();

  // Form controllers Modo Consulta y Pago
  final _formKeyConsulta = GlobalKey<FormState>();
  final _codSocioConsultaController = TextEditingController();
  final _aliasConsultaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codSocioTitularController.dispose();
    _ciMedidorController.dispose();
    _aliasTitularController.dispose();
    _codSocioConsultaController.dispose();
    _aliasConsultaController.dispose();
    super.dispose();
  }

  Future<void> _vincularTitular() async {
    if (!_formKeyTitular.currentState!.validate()) return;

    final success =
        await ref.read(multicuentaProvider.notifier).vincularSuministro(
              codSocio: _codSocioTitularController.text.trim(),
              ciOMedidor: _ciMedidorController.text.trim(),
              alias: _aliasTitularController.text.trim().isNotEmpty
                  ? _aliasTitularController.text.trim()
                  : 'Mi Suministro',
            );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suministro vinculado correctamente en Modo Titular'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      context.pop();
    } else {
      final errorMsg = ref.read(multicuentaProvider).errorMessage ??
          'No se pudo vincular el suministro.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _vincularConsulta() async {
    if (!_formKeyConsulta.currentState!.validate()) return;

    final success =
        await ref.read(multicuentaProvider.notifier).vincularSuministro(
              codSocio: _codSocioConsultaController.text.trim(),
              ciOMedidor: null, // Sin CI = CONSULTA_PAGO
              alias: _aliasConsultaController.text.trim().isNotEmpty
                  ? _aliasConsultaController.text.trim()
                  : 'Suministro Consulta',
            );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suministro vinculado correctamente en Modo Consulta y Pago'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      context.pop();
    } else {
      final errorMsg = ref.read(multicuentaProvider).errorMessage ??
          'No se pudo vincular el suministro.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(multicuentaProvider);

    return Scaffold(
      appBar: CosmolAppBar(
        title: 'COSMOL R.L.',
        subtitle: 'Vincular Suministro',
        showBackButton: true,
        onBackPressed: () => context.pop(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle:
                    AppTextStyles.subtitle2.copyWith(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Modo Titular'),
                  Tab(text: 'Consulta y Pago'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Pestaña 1: Modo Titular
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKeyTitular,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primary.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_outlined,
                                    color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Al validar tu CI o N° Medidor de Titular, tendrás acceso completo a facturas oficiales en PDF y avisos de corte.',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          CosmolTextField(
                            controller: _codSocioTitularController,
                            label: 'Código de Socio',
                            hint: 'Ej. 104523',
                            prefixIcon: Icons.water_drop_outlined,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese el código de socio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CosmolTextField(
                            controller: _ciMedidorController,
                            label: 'CI o N° Medidor del Titular',
                            hint: 'Ej. 8392019 o M-4091',
                            prefixIcon: Icons.badge_outlined,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese la CI o número de medidor del titular';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CosmolTextField(
                            controller: _aliasTitularController,
                            label: 'Alias Personalizado',
                            hint: 'Ej. Casa Principal, Negocio Norte',
                            prefixIcon: Icons.label_outline_rounded,
                          ),
                          const SizedBox(height: 28),
                          CosmolButton(
                            text: 'Vincular como Titular',
                            isLoading: state.isLoading,
                            onPressed: _vincularTitular,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pestaña 2: Modo Consulta y Pago (Inquilino)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKeyConsulta,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.warningBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.warningOrange.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: AppColors.warningOrange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Modo Inquilino / Pagador: Podrás consultar la deuda y pagar mediante QR sin exponer datos confidenciales ni CI del titular.',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          CosmolTextField(
                            controller: _codSocioConsultaController,
                            label: 'Código de Socio',
                            hint: 'Ej. 104523',
                            prefixIcon: Icons.water_drop_outlined,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese el código de socio';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CosmolTextField(
                            controller: _aliasConsultaController,
                            label: 'Alias Personalizado',
                            hint: 'Ej. Departamento Alquiler, Local Comercial',
                            prefixIcon: Icons.label_outline_rounded,
                          ),
                          const SizedBox(height: 28),
                          CosmolButton(
                            text: 'Vincular para Consulta y Pago',
                            isLoading: state.isLoading,
                            onPressed: _vincularConsulta,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
