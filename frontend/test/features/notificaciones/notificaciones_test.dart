import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosmol_app/core/config/theme/app_theme.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/deuda/data/models/resumen_deuda_model.dart';
import 'package:cosmol_app/features/deuda/domain/repositories/deuda_repository.dart';
import 'package:cosmol_app/features/deuda/presentation/providers/deuda_provider.dart';
import 'package:cosmol_app/features/multicuenta/domain/repositories/multicuenta_repository.dart';
import 'package:cosmol_app/features/multicuenta/presentation/providers/multicuenta_provider.dart';
import 'package:cosmol_app/features/notificaciones/data/models/notificacion_item_model.dart';
import 'package:cosmol_app/features/notificaciones/presentation/providers/notificaciones_provider.dart';
import 'package:cosmol_app/features/notificaciones/presentation/widgets/notificaciones_bell_icon.dart';
import 'package:cosmol_app/features/reconexion/data/models/elegibilidad_reconexion_model.dart';
import 'package:cosmol_app/features/reconexion/data/models/reconexion_tramite_model.dart';
import 'package:cosmol_app/features/reconexion/data/models/solicitud_reconexion_model.dart';
import 'package:cosmol_app/features/reconexion/data/repositories/reconexion_repository_impl.dart';
import 'package:cosmol_app/features/reconexion/domain/repositories/reconexion_repository.dart';
import 'package:cosmol_app/features/reconexion/presentation/providers/reconexion_provider.dart';

class _FakeStorageService implements StorageService {
  Set<String> _readIds = {};

  @override
  Future<void> init() async {}
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> clearAuthData() async {}
  @override
  Future<void> saveActiveCodSocio(String codSocio) async {}
  @override
  Future<String?> getActiveCodSocio() async => '267657';
  @override
  Future<void> saveDeviceId(String deviceId) async {}
  @override
  Future<String?> getDeviceId() async => 'test';
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
  Future<void> saveReadNotificationIds(Set<String> ids) async {
    _readIds = Set<String>.from(ids);
  }

  @override
  Set<String> getReadNotificationIds() => _readIds;
}

class _FakeMulticuentaRepository implements MulticuentaRepository {
  final List<SuministroModel> suministros;
  _FakeMulticuentaRepository(this.suministros);

  @override
  Future<List<SuministroModel>> listarSuministros() async => suministros;

  @override
  Future<SuministroModel> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) async =>
      suministros.first;

  @override
  Future<void> desvincularSuministro(String codSocio) async {}
}

class _FakeDeudaRepository implements DeudaRepository {
  final ResumenDeudaModel? resumen;
  _FakeDeudaRepository(this.resumen);

  @override
  Future<ResumenDeudaModel> obtenerDeudaSuministro({
    required String codSocio,
    bool forzarRefresco = false,
  }) async {
    return resumen ??
        const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 0.0,
          cantidadFacturasPendientes: 0,
          estaVencido: false,
          alertaCorte: false,
        );
  }

  @override
  Future<void> invalidarCacheDeuda({required String codSocio}) async {}
}

class _FakeReconexionRepository implements ReconexionRepository {
  final List<ReconexionTramiteModel> tramites = const [];
  _FakeReconexionRepository();

  @override
  Future<ElegibilidadReconexionModel> checkElegibilidad(String codSocio) async =>
      const ElegibilidadReconexionModel(
        codigoSocio: '267657',
        esElegible: true,
        mensajeUsuario: 'Elegible',
      );

  @override
  Future<List<ReconexionTramiteModel>> getHistorial(String codSocio) async => tramites;

  @override
  Future<String> subirFotoEvidencia({
    required dynamic bytes,
    required String filename,
    required String codSocio,
  }) async =>
      'http://minio/foto.jpg';

  @override
  Future<RespuestaSolicitudReconexionModel> solicitarReconexion(
    SolicitudReconexionPayload payload,
  ) async =>
      const RespuestaSolicitudReconexionModel(
        idReconexion: 5555,
        estado: 'PENDIENTE',
        facturasPendientes: 1,
        mensaje: 'Registrado',
      );
}

void main() {
  group('Notificaciones Module Tests', () {
    const supplyTitular = SuministroModel(
      id: 'sum-1',
      codSocio: '267657',
      alias: 'Mi Casa',
      nombre: 'JUAN PEREZ',
      rol: 'TITULAR',
      esSuministroPrincipal: true,
    );

    test('NotificacionesNotifier genera Aviso de Corte cuando hay 2 o mas facturas impagas', () {
      final fakeStorage = _FakeStorageService();
      final multiState = const MulticuentaState(
        suministros: [supplyTitular],
        activeSuministro: supplyTitular,
      );
      final deudaState = DeudaState(
        resumenDeuda: const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 170.0,
          cantidadFacturasPendientes: 2,
          estaVencido: true,
          alertaCorte: true,
        ),
      );
      final reconexionState = const ReconexionState();

      final notifier = NotificacionesNotifier(
        storageService: fakeStorage,
        multicuentaState: multiState,
        deudaState: deudaState,
        reconexionState: reconexionState,
      );

      expect(notifier.state.notificaciones.length, 1);
      final notif = notifier.state.notificaciones.first;
      expect(notif.tipo, TipoNotificacion.avisoCorte);
      expect(notif.titulo, contains('Aviso de Corte'));
      expect(notif.esUrgente, true);
      expect(notif.esLeida, false);
      expect(notifier.state.unreadCount, 1);
    });

    test('NotificacionesNotifier genera Factura Vencida cuando hay 1 impaga vencida', () {
      final fakeStorage = _FakeStorageService();
      final multiState = const MulticuentaState(
        suministros: [supplyTitular],
        activeSuministro: supplyTitular,
      );
      final deudaState = DeudaState(
        resumenDeuda: const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 85.0,
          cantidadFacturasPendientes: 1,
          estaVencido: true,
          alertaCorte: false,
        ),
      );

      final notifier = NotificacionesNotifier(
        storageService: fakeStorage,
        multicuentaState: multiState,
        deudaState: deudaState,
        reconexionState: const ReconexionState(),
      );

      expect(notifier.state.notificaciones.length, 1);
      final notif = notifier.state.notificaciones.first;
      expect(notif.tipo, TipoNotificacion.facturaVencida);
      expect(notif.titulo, 'Factura Vencida');
      expect(notif.esUrgente, true);
    });

    test('NotificacionesNotifier genera Suministro al Día cuando no hay deudas', () {
      final fakeStorage = _FakeStorageService();
      final multiState = const MulticuentaState(
        suministros: [supplyTitular],
        activeSuministro: supplyTitular,
      );
      final deudaState = DeudaState(
        resumenDeuda: const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 0.0,
          cantidadFacturasPendientes: 0,
          estaVencido: false,
          alertaCorte: false,
        ),
      );

      final notifier = NotificacionesNotifier(
        storageService: fakeStorage,
        multicuentaState: multiState,
        deudaState: deudaState,
        reconexionState: const ReconexionState(),
      );

      expect(notifier.state.notificaciones.length, 1);
      final notif = notifier.state.notificaciones.first;
      expect(notif.tipo, TipoNotificacion.alDia);
      expect(notif.titulo, contains('al Día'));
      expect(notif.esUrgente, false);
    });

    test('Persistencia: una notificacion leida no cuenta para unreadCount', () async {
      final fakeStorage = _FakeStorageService();
      const notifId = 'corte_267657_cant2_saldo170';
      await fakeStorage.saveReadNotificationIds({notifId});

      final multiState = const MulticuentaState(
        suministros: [supplyTitular],
        activeSuministro: supplyTitular,
      );
      final deudaState = DeudaState(
        resumenDeuda: const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 170.0,
          cantidadFacturasPendientes: 2,
          estaVencido: true,
          alertaCorte: true,
        ),
      );

      final notifier = NotificacionesNotifier(
        storageService: fakeStorage,
        multicuentaState: multiState,
        deudaState: deudaState,
        reconexionState: const ReconexionState(),
      );

      expect(notifier.state.notificaciones.length, 1);
      final notif = notifier.state.notificaciones.first;
      expect(notif.esLeida, true);
      expect(notifier.state.unreadCount, 0);
    });

    test('marcarTodasComoLeidas actualiza unreadCount a 0 y persiste en StorageService', () async {
      final fakeStorage = _FakeStorageService();
      final multiState = const MulticuentaState(
        suministros: [supplyTitular],
        activeSuministro: supplyTitular,
      );
      final deudaState = DeudaState(
        resumenDeuda: const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 170.0,
          cantidadFacturasPendientes: 2,
          estaVencido: true,
          alertaCorte: true,
        ),
      );

      final notifier = NotificacionesNotifier(
        storageService: fakeStorage,
        multicuentaState: multiState,
        deudaState: deudaState,
        reconexionState: const ReconexionState(),
      );

      expect(notifier.state.unreadCount, 1);
      await notifier.marcarTodasComoLeidas();
      expect(notifier.state.unreadCount, 0);
      expect(fakeStorage.getReadNotificationIds().isNotEmpty, true);
    });

    testWidgets('NotificacionesBellIcon muestra badge rojo cuando hay no leidas', (tester) async {
      final fakeStorage = _FakeStorageService();
      final fakeMultiRepo = _FakeMulticuentaRepository([supplyTitular]);
      final fakeDeudaRepo = _FakeDeudaRepository(
        const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 170.0,
          cantidadFacturasPendientes: 2,
          estaVencido: true,
          alertaCorte: true,
        ),
      );

      final deudaNotif = DeudaNotifier(fakeDeudaRepo);
      await deudaNotif.cargarDeuda('267657');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            multicuentaProvider.overrideWith(
              (ref) => MulticuentaNotifier(
                repository: fakeMultiRepo,
                storageService: fakeStorage,
                initialSuministros: [supplyTitular],
                initialCodSocio: '267657',
              ),
            ),
            deudaProvider.overrideWith((ref) => deudaNotif),
            reconexionRepositoryProvider.overrideWithValue(_FakeReconexionRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: NotificacionesBellIcon(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el ícono de campanita
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      // Debe mostrar el badge con el número '1'
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Tocar NotificacionesBellIcon abre NotificacionesSheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeStorage = _FakeStorageService();
      final fakeMultiRepo = _FakeMulticuentaRepository([supplyTitular]);
      final fakeDeudaRepo = _FakeDeudaRepository(
        const ResumenDeudaModel(
          codSocio: '267657',
          saldoPendienteBs: 170.0,
          cantidadFacturasPendientes: 2,
          estaVencido: true,
          alertaCorte: true,
        ),
      );

      final deudaNotif = DeudaNotifier(fakeDeudaRepo);
      await deudaNotif.cargarDeuda('267657');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            multicuentaProvider.overrideWith(
              (ref) => MulticuentaNotifier(
                repository: fakeMultiRepo,
                storageService: fakeStorage,
                initialSuministros: [supplyTitular],
                initialCodSocio: '267657',
              ),
            ),
            deudaProvider.overrideWith((ref) => deudaNotif),
            reconexionRepositoryProvider.overrideWithValue(_FakeReconexionRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Center(
                child: NotificacionesBellIcon(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tocar la campanita
      await tester.tap(find.byType(NotificacionesBellIcon));
      await tester.pumpAndSettle();

      // Debe abrir el sheet con el título 'Notificaciones'
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.textContaining('Aviso de Corte'), findsOneWidget);
      expect(find.text('Pagar con QR'), findsOneWidget);
    });
  });
}
