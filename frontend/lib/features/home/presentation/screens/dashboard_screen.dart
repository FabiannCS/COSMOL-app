import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../widgets/consumo_tab_content.dart';
import '../widgets/deuda_tab_content.dart';
import '../widgets/documentos_tab_content.dart';
import '../widgets/perfil_tab_content.dart';
import '../widgets/suministros_tab_content.dart';

/// Shell Principal del Dashboard post-login con Navegación Inferior Fija.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final multicuentaState = ref.watch(multicuentaProvider);
    final activeSuministro = multicuentaState.activeSuministro;

    return Scaffold(
      appBar: _currentIndex == 0
          ? CosmolAppBar(
              title: 'COSMOL R.L.',
              subtitle: _getSocioNombre(activeSuministro),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.onSurfaceVariant),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No tienes notificaciones pendientes.'),
                      ),
                    );
                  },
                ),
              ],
            )
          : CosmolAppBar(
              title: 'COSMOL R.L.',
              subtitle: _getAppBarTitle(_currentIndex),
              actions: [
                if (_currentIndex == 3)
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                    onPressed: () => context.push('/suministros/vincular'),
                  ),
              ],
            ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 0: Deuda / Inicio
            DeudaTabContent(
              activeSuministro: activeSuministro,
              onVerRecibo: () {
                setState(() {
                  _currentIndex = 2; // Ir a Documentos
                });
              },
            ),

            // Tab 1: Consumo Analítico (Fase 2)
            const ConsumoTabContent(),

            // Tab 2: Documentos y Facturas PDF (Fase 2)
            const DocumentosTabContent(),

            // Tab 3: Gestión Multicuenta
            SuministrosTabContent(
              multicuentaState: multicuentaState,
              onSuministroSeleccionado: () {
                setState(() {
                  _currentIndex = 0; // Regresar a Deuda/Inicio
                });
              },
            ),

            // Tab 4: Perfil de Socio
            PerfilTabContent(
              activeSuministro: activeSuministro,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardSurface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Deuda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Consumo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Documentos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.layers_outlined),
              activeIcon: Icon(Icons.layers_rounded),
              label: 'Suministros',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 1:
        return 'Historial de Consumo';
      case 2:
        return 'Facturas y Avisos';
      case 3:
        return 'Mis Suministros';
      case 4:
        return 'Perfil del Socio';
      default:
        return 'COSMOL R.L.';
    }
  }

  String _getSocioNombre(dynamic activeSuministro) {
    if (activeSuministro == null) return 'Socio Digital';

    final cod = activeSuministro.codSocio?.toString().trim() ?? '';

    // Mapeo de nombres oficiales del padrón comercial de COSMOL para socios de prueba
    const knownNames = {
      '540': 'DURAN ELOISA RIVERA',
      '104523': 'CARLOS EDUARDO PEREZ',
      '205566': 'MARIA ELENA ROJAS',
      '301144': 'JUAN PABLO SUAREZ',
      '556': 'SUAREZ BALTAZAR VICTOR HUGO',
    };

    if (knownNames.containsKey(cod)) {
      return knownNames[cod]!;
    }

    if (activeSuministro.alias != null &&
        activeSuministro.alias.toString().isNotEmpty &&
        !activeSuministro.alias.toString().startsWith('Suministro')) {
      return activeSuministro.alias.toString();
    }

    return 'Socio $cod';
  }
}
