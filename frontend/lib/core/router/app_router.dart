import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/onboarding_step2_screen.dart';
import '../../features/home/presentation/screens/dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (BuildContext context, GoRouterState state) {
      final status = authState.status;
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');

      if (status == AuthStatus.initial) {
        return isSplash || isLoggingIn || isOnboarding ? null : '/login';
      }

      if (status == AuthStatus.unauthenticated || status == AuthStatus.locked) {
        return isLoggingIn || isOnboarding ? null : '/login';
      }

      if (status == AuthStatus.onboardingRequired) {
        return isOnboarding ? null : '/onboarding';
      }

      if (status == AuthStatus.authenticated) {
        if (isSplash || isLoggingIn || isOnboarding) {
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
    ],
  );
});
