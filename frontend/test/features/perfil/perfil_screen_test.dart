import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cosmol_app/core/config/theme/app_colors.dart';
import 'package:cosmol_app/core/config/theme/app_theme.dart';
import 'package:cosmol_app/core/router/app_router.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/core/widgets/cosmol_app_bar.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/deuda/data/models/resumen_deuda_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/deuda_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/deuda_provider.dart';
import 'package:cosmol_app/features/perfil/presentation/screens/perfil_screen.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final ResumenDeudaModel response;

  _FakeDeudaRepository(this.response);

  @override
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    return response;
  }

  @override
  Future<void> invalidarCacheDeuda({required String codSocio}) async {}
}

class _FakeStorageService implements StorageService {
  @override
  Future<void> init() async {}

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> clearAuthData() async {}

  @override
  Future<void> saveActiveCodSocio(String codSocio) async {}

  @override
  Future<String?> getActiveCodSocio() async => null;

  @override
  Future<void> saveDeviceId(String deviceId) async {}

  @override
  Future<String?> getDeviceId() async => 'test-device';

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;

  @override
  Future<void> saveCachedDeuda(String codSocio, Map<String, dynamic> data) async {}

  @override
  Map<String, dynamic>? getCachedDeuda(String codSocio) => null;

  @override
  DateTime? getDeudaSyncTime(String codSocio) => null;

  @override
  Future<void> saveCachedSuministros(List<Map<String, dynamic>> data) async {}

  @override
  List<Map<String, dynamic>>? getCachedSuministros() => null;

  @override
  Future<void> saveReadNotificationIds(Set<String> ids) async {}

  @override
  Set<String> getReadNotificationIds() => <String>{};
}

void main() {
  group('PerfilScreen y AppBar de Mi Perfil', () {
    testWidgets(
      'muestra teléfono registrado del titular y oculta visualmente autenticación biométrica',
      (WidgetTester tester) async {
        const activeSuministro = SuministroModel(
          id: 'sum-785',
          codSocio: '785',
          alias: 'Casa',
          nombre: 'LIMA LOPEZ MOISES',
          rol: 'TITULAR',
          esSuministroPrincipal: true,
        );

        const resumenMock = ResumenDeudaModel(
          codSocio: '785',
          suministro: DetalleSuministroModel(
            codSocio: '785',
            nombreTitular: 'LIMA LOPEZ MOISES',
            ciNit: '552840',
            direccion: 'ANTOFAGASTA /24 DE S',
            ubicacion: '1.6.38.0',
            rolUsuario: 'TITULAR',
            telefonoCelular: '+59160968075',
          ),
          saldoPendienteBs: 0.0,
          cantidadFacturasPendientes: 0,
          estaVencido: false,
          alertaCorte: false,
        );

        final notifier = DeudaNotifier(_FakeDeudaRepository(resumenMock));
        await notifier.cargarDeuda('785');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(_FakeStorageService()),
              deudaProvider.overrideWith((ref) => notifier),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                backgroundColor: AppColors.lightBackground,
                appBar: const CosmolAppBar(
                  title: 'Mi Perfil',
                  showBackButton: true,
                ),
                body: const PerfilScreen(activeSuministro: activeSuministro),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Teléfono registrado visible en Información del Socio
        expect(find.text('Información del Socio'), findsOneWidget);
        expect(find.text('+59160968075'), findsOneWidget);
        expect(find.text('No registrado'), findsNothing);

        // 2. Autenticación Biométrica oculta visualmente, Cambiar PIN sigue visible
        expect(find.text('Seguridad y Cuenta'), findsOneWidget);
        expect(find.text('Autenticación Biométrica'), findsNothing);
        expect(find.text('Huella o reconocimiento facial'), findsNothing);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.text('Cambiar PIN / Contraseña'), findsOneWidget);

        // 3. Flecha de retroceso visible con color oscuro sobre superficie blanca
        final backIconFinder = find.byIcon(Icons.arrow_back);
        expect(backIconFinder, findsOneWidget);
        final backIcon = tester.widget<Icon>(backIconFinder);
        expect(backIcon.color, AppColors.onSurface);
        expect(backIcon.color, isNot(AppColors.pureWhite));
      },
    );

    testWidgets(
      'ruta /perfil en AppRouter muestra botón volver visible y regresa al pulsarlo',
      (WidgetTester tester) async {
        const resumenMock = ResumenDeudaModel(
          codSocio: '785',
          suministro: DetalleSuministroModel(
            codSocio: '785',
            nombreTitular: 'LIMA LOPEZ MOISES',
            ciNit: '552840',
            direccion: 'ANTOFAGASTA /24 DE S',
            ubicacion: '1.6.38.0',
            rolUsuario: 'TITULAR',
            telefonoCelular: '+59160968075',
          ),
          saldoPendienteBs: 0.0,
          cantidadFacturasPendientes: 0,
          estaVencido: false,
          alertaCorte: false,
        );

        final notifier = DeudaNotifier(_FakeDeudaRepository(resumenMock));
        await notifier.cargarDeuda('785');

        GoRouter? perfilRouter;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(_FakeStorageService()),
              deudaProvider.overrideWith((ref) => notifier),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                if (perfilRouter == null) {
                  final appRouter = ref.read(appRouterProvider);
                  final perfilRoute = appRouter.configuration.routes
                      .whereType<GoRoute>()
                      .firstWhere((r) => r.path == '/perfil');

                  perfilRouter = GoRouter(
                    initialLocation: '/',
                    routes: [
                      GoRoute(
                        path: '/',
                        builder: (navContext, _) => Scaffold(
                          body: ElevatedButton(
                            onPressed: () => navContext.push('/perfil'),
                            child: const Text('Ir'),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: '/perfil',
                        builder: perfilRoute.builder!,
                      ),
                    ],
                  );
                }

                return MaterialApp.router(
                  theme: AppTheme.lightTheme,
                  routerConfig: perfilRouter,
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Ir'));
        await tester.pumpAndSettle();

        expect(find.text('Mi Perfil'), findsOneWidget);
        expect(find.text('+59160968075'), findsOneWidget);
        expect(find.text('Autenticación Biométrica'), findsNothing);

        final backBtnFinder = find.byIcon(Icons.arrow_back);
        expect(backBtnFinder, findsOneWidget);
        final backIcon = tester.widget<Icon>(backBtnFinder);
        expect(backIcon.color, AppColors.onSurface);

        await tester.tap(backBtnFinder);
        await tester.pumpAndSettle();

        expect(find.text('Ir'), findsOneWidget);
      },
    );

    testWidgets(
      'en modo consulta, PerfilScreen muestra banner de privacidad, oculta teléfono y cambiar PIN, y censura dirección',
      (WidgetTester tester) async {
        const activeSuministro = SuministroModel(
          id: 'sum-999',
          codSocio: '999',
          alias: 'Alquiler',
          nombre: 'PEREZ JUAN',
          rol: 'CONSULTA_PAGO',
          esSuministroPrincipal: false,
        );

        const resumenMock = ResumenDeudaModel(
          codSocio: '999',
          suministro: DetalleSuministroModel(
            codSocio: '999',
            nombreTitular: 'P***Z J**N',
            ciNit: '***840',
            direccion: 'ANTOFAGASTA / 24 DE S',
            ubicacion: '1.6.38.0',
            rolUsuario: 'CONSULTA_PAGO',
            telefonoCelular: '',
          ),
          saldoPendienteBs: 150.0,
          cantidadFacturasPendientes: 1,
          estaVencido: false,
          alertaCorte: false,
        );

        final notifier = DeudaNotifier(_FakeDeudaRepository(resumenMock));
        await notifier.cargarDeuda('999');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(_FakeStorageService()),
              deudaProvider.overrideWith((ref) => notifier),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                backgroundColor: AppColors.lightBackground,
                appBar: const CosmolAppBar(
                  title: 'Mi Perfil',
                  showBackButton: true,
                ),
                body: const PerfilScreen(activeSuministro: activeSuministro),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Banner "Modo Consulta y Pago Activo" debe estar visible en Perfil
        expect(find.text('Modo Consulta y Pago Activo'), findsOneWidget);

        // 2. Información del Socio: Rol debe ser Consulta y Pago, Teléfono debe estar oculto
        expect(find.text('Información del Socio'), findsOneWidget);
        expect(find.text('Consulta y Pago'), findsOneWidget);
        expect(find.text('Teléfono'), findsNothing);

        // 3. Dirección censurada palabra por palabra (primera y última letra)
        // 'ANTOFAGASTA / 24 DE S' -> 'A*********A / 2* D* S'
        expect(find.text('A*********A / 2* D* S'), findsOneWidget);

        // 4. Seguridad y Cuenta / Cambiar PIN debe estar completamente oculto
        expect(find.text('Seguridad y Cuenta'), findsNothing);
        expect(find.text('Cambiar PIN / Contraseña'), findsNothing);
      },
    );

    testWidgets(
      'en modo titular secundario, PerfilScreen muestra teléfono y datos pero oculta cambiar PIN',
      (WidgetTester tester) async {
        const activeSuministro = SuministroModel(
          id: 'sum-786',
          codSocio: '786',
          alias: 'Oficina',
          nombre: 'LIMA LOPEZ MOISES',
          rol: 'TITULAR',
          esSuministroPrincipal: false, // Titular secundario
        );

        const resumenMock = ResumenDeudaModel(
          codSocio: '786',
          suministro: DetalleSuministroModel(
            codSocio: '786',
            nombreTitular: 'LIMA LOPEZ MOISES',
            ciNit: '552840',
            direccion: 'CALLE COMERCIO 123',
            ubicacion: '1.6.38.0',
            rolUsuario: 'TITULAR',
            telefonoCelular: '+59160968075',
          ),
          saldoPendienteBs: 0.0,
          cantidadFacturasPendientes: 0,
          estaVencido: false,
          alertaCorte: false,
        );

        final notifier = DeudaNotifier(_FakeDeudaRepository(resumenMock));
        await notifier.cargarDeuda('786');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(_FakeStorageService()),
              deudaProvider.overrideWith((ref) => notifier),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                backgroundColor: AppColors.lightBackground,
                appBar: const CosmolAppBar(
                  title: 'Mi Perfil',
                  showBackButton: true,
                ),
                body: const PerfilScreen(activeSuministro: activeSuministro),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Rol de Usuario debe decir Titular Secundario
        expect(find.text('Titular Secundario'), findsOneWidget);

        // 2. Teléfono sí se muestra porque es Titular
        expect(find.text('+59160968075'), findsOneWidget);

        // 3. Dirección sin censura porque es Titular
        expect(find.text('CALLE COMERCIO 123'), findsOneWidget);

        // 4. Cambiar PIN y Seguridad y Cuenta deben estar OCULTOS para titular secundario
        expect(find.text('Seguridad y Cuenta'), findsNothing);
        expect(find.text('Cambiar PIN / Contraseña'), findsNothing);
      },
    );
  });
}
