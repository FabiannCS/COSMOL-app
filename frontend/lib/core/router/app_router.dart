import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/onboarding_step2_screen.dart';
import '../../features/auth/presentation/screens/recuperar_password_screen.dart';
import '../../features/auth/presentation/screens/migrar_celular_screen.dart';
import '../../features/home/presentation/screens/dashboard_screen.dart';
import '../../features/multicuenta/presentation/screens/supplies_list_screen.dart';
import '../../features/multicuenta/presentation/screens/bind_supply_screen.dart';
import '../../features/documentos/data/models/documento_model.dart';
import '../../features/documentos/presentation/screens/pdf_viewer_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      final status = authState.status;
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');
      final isRecuperarPassword =
          state.matchedLocation.startsWith('/recuperar-password');
      final isMigrarCelular =
          state.matchedLocation.startsWith('/migrar-celular');

      if (status == AuthStatus.initial) {
        return isSplash ? null : '/splash';
      }

      if (status == AuthStatus.unauthenticated || status == AuthStatus.locked) {
        return isLoggingIn || isOnboarding || isRecuperarPassword || isMigrarCelular ? null : '/login';
      }

      if (status == AuthStatus.onboardingRequired) {
        return isOnboarding ? null : '/onboarding';
      }

      if (status == AuthStatus.authenticated) {
        if (isSplash || isLoggingIn || isOnboarding || isRecuperarPassword || isMigrarCelular) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/recuperar-password',
        name: 'recuperar-password',
        builder: (context, state) => const RecuperarPasswordScreen(),
      ),
      GoRoute(
        path: '/migrar-celular',
        name: 'migrar-celular',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MigrarCelularScreen(
            initialCodSocio: extra?['cod_socio'] as String?,
            initialCi: extra?['ci'] as String?,
            nombreTitular: extra?['nombre_titular'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
        routes: [
          GoRoute(
            path: 'step2',
            name: 'onboarding-step2',
            builder: (context, state) => const OnboardingStep2Screen(),
          ),
        ],
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/suministros',
        name: 'suministros',
        builder: (context, state) => const SuppliesListScreen(),
        routes: [
          GoRoute(
            path: 'vincular',
            name: 'vincular-suministro',
            builder: (context, state) => const BindSupplyScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/documentos/visor',
        name: 'visor-documento',
        builder: (context, state) {
          final documento = state.extra as DocumentoModel?;
          if (documento == null) {
            return const Scaffold(
              body: Center(child: Text('Documento no especificado')),
            );
          }
          return PdfViewerScreen(documento: documento);
        },
      ),
    ],
  );
});


