import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de servicios asíncronos de persistencia
  final container = ProviderContainer();
  await container.read(storageServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CosmolApp(),
    ),
  );
}

class CosmolApp extends ConsumerWidget {
  const CosmolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'COSMOL R.L. - App de Socios',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
