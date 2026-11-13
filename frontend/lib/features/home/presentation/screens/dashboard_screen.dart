import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../consumo/presentation/screens/consumo_screen.dart';
import '../../../deuda/presentation/providers/deuda_provider.dart';
import '../../../deuda/presentation/screens/deuda_screen.dart';
import '../../../documentos/presentation/screens/documentos_screen.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../../multicuenta/presentation/screens/supplies_list_screen.dart';
import '../../../reconexion/presentation/screens/reconexion_status_screen.dart';

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
    final isTitular = activeSuministro?.rol.toUpperCase() == 'TITULAR';

    final deudaState = ref.watch(deudaProvider);
    final titularBackend = deudaState.resumenDeuda?.suministro?.nombreTitular;

    final List<Widget> bodyTabs = [
      // Tab Deuda / Inicio
      DeudaScreen(
        activeSuministro: activeSuministro,
        onVerRecibo: () {
          if (isTitular) {
            setState(() {
              _currentIndex = 2; // Ir a Documentos
            });
          }
        },
      ),

      // Tab Consumo Analítico
      ConsumoScreen(
        onVerFacturas: () {
          if (isTitular) {
            setState(() {
              _currentIndex = 2; // Ir a Documentos
            });
          }
        },
      ),

      // Tab Documentos (Solo Titulares)
      if (isTitular) const DocumentosScreen(),

      // Tab Gestión Multicuenta
      SuppliesListScreen(
        isEmbedded: true,
        onSuministroSeleccionado: () {
          setState(() {
            _currentIndex = 0; // Regresar a Deuda/Inicio
          });
        },
      ),

      // Tab Reconexión de Servicio (Solo Titulares)
      if (isTitular)
        const ReconexionStatusScreen(
          isEmbedded: true,
        ),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_wallet_outlined),
        activeIcon: Icon(Icons.account_balance_wallet_rounded),
        label: 'Deuda',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.bar_chart_outlined),
        activeIcon: Icon(Icons.bar_chart_rounded),
        label: 'Consumo',
      ),
      if (isTitular)
        const BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long_rounded),
          label: 'Documentos',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.layers_outlined),
        activeIcon: Icon(Icons.layers_rounded),
        label: 'Socios',
      ),
      if (isTitular)
        const BottomNavigationBarItem(
          icon: Icon(Icons.build_outlined),
          activeIcon: Icon(Icons.build_rounded),
          label: 'Reconexión',
        ),
    ];

    final safeIndex = _currentIndex < bodyTabs.length ? _currentIndex : 0;
    final isSociosTab = isTitular ? safeIndex == 3 : safeIndex == 2;

    return Scaffold(
      appBar: CosmolAppBar(
        title: 'COSMOL R.L.',
        subtitle: _getSocioNombre(activeSuministro,
            titularBackend: titularBackend),
        actions: [
          if (isSociosTab)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () => context.push('/suministros/vincular'),
            )
          else
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.onSurfaceVariant),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No tienes notificaciones pendientes.'),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: AppColors.primary, size: 26),
            tooltip: 'Mi Perfil',
            onPressed: () => context.push('/perfil'),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: safeIndex,
          children: bodyTabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
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
          items: navItems,
        ),
      ),
    );
  }

  String _getSocioNombre(dynamic activeSuministro, {String? titularBackend}) {
    if (titularBackend != null && titularBackend.trim().isNotEmpty) {
      return titularBackend.trim();
    }

    if (activeSuministro == null) return 'Socio Digital';

    final cod = activeSuministro.codSocio?.toString().trim() ?? '';

    if (activeSuministro.alias != null &&
        activeSuministro.alias.toString().isNotEmpty &&
        !activeSuministro.alias.toString().startsWith('Suministro')) {
      return activeSuministro.alias.toString();
    }

    return 'Socio $cod';
  }
}
