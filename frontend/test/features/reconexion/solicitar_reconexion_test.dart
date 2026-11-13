import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cosmol_app/core/config/theme/app_theme.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/multicuenta/domain/repositories/multicuenta_repository.dart';
import 'package:cosmol_app/features/multicuenta/presentation/providers/multicuenta_provider.dart';
import 'package:cosmol_app/features/reconexion/data/models/elegibilidad_reconexion_model.dart';
import 'package:cosmol_app/features/reconexion/data/models/reconexion_tramite_model.dart';
import 'package:cosmol_app/features/reconexion/data/models/solicitud_reconexion_model.dart';
import 'package:cosmol_app/features/reconexion/data/repositories/reconexion_repository_impl.dart';
import 'package:cosmol_app/features/reconexion/domain/repositories/reconexion_repository.dart';
import 'package:cosmol_app/features/reconexion/presentation/providers/reconexion_provider.dart';
import 'package:cosmol_app/features/reconexion/presentation/screens/solicitar_reconexion_screen.dart';

class _FakeReconexionRepository implements ReconexionRepository {
  @override
  Future<ElegibilidadReconexionModel> checkElegibilidad(String codSocio) async {
    return const ElegibilidadReconexionModel(
      codigoSocio: '267657',
      esElegible: true,
      mensajeUsuario: 'Elegible',
    );
  }

  @override
  Future<List<ReconexionTramiteModel>> getHistorial(String codSocio) async => [];

  @override
  Future<String> subirFotoEvidencia({
    required Uint8List bytes,
    required String filename,
    required String codSocio,
  }) async =>
      'https://minio.cosmol.com/uploads/foto.jpg';

  @override
  Future<RespuestaSolicitudReconexionModel> solicitarReconexion(
    SolicitudReconexionPayload payload,
  ) async {
    return const RespuestaSolicitudReconexionModel(
      idReconexion: 5555,
      estado: 'PENDIENTE',
      facturasPendientes: 1,
      mensaje: 'Trámite registrado',
    );
  }
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

class _FakeStorageService implements StorageService {
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
}

void main() {
  group('SolicitarReconexionScreen - Fotos Obligatorias', () {
    const supply = SuministroModel(
      id: 'sum-1',
      codSocio: '267657',
      alias: 'Mi Casa',
      nombre: 'JUAN PEREZ',
      rol: 'TITULAR',
      esSuministroPrincipal: true,
    );

    testWidgets('muestra badge Obligatorio en el selector de fotografía', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeStorage = _FakeStorageService();
      final fakeMultiRepo = _FakeMulticuentaRepository([supply]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            reconexionRepositoryProvider.overrideWithValue(_FakeReconexionRepository()),
            multicuentaProvider.overrideWith(
              (ref) => MulticuentaNotifier(
                repository: fakeMultiRepo,
                storageService: fakeStorage,
                initialSuministros: [supply],
                initialCodSocio: '267657',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SolicitarReconexionScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fotografía del medidor / fachada'), findsOneWidget);
      expect(find.text('Obligatorio'), findsOneWidget);
      expect(find.text('Adjuntada'), findsNothing);
    });

    test('ReconexionNotifier bloquea el registro si fotoBytes es nulo o vacío', () async {
      final fakeRepo = _FakeReconexionRepository();
      final notifier = ReconexionNotifier(fakeRepo);

      final result = await notifier.registrarSolicitud(
        codSocio: '267657',
        idTipoReconexion: 1,
        coordenadasGps: '-17.34, -63.25',
        glosa: 'Casa blanca portón rejas',
        fotoBytes: null,
      );

      expect(result, false);
      expect(notifier.state.errorMessage, 'Debe adjuntar una fotografía de evidencia (obligatoria).');

      final resultVacio = await notifier.registrarSolicitud(
        codSocio: '267657',
        idTipoReconexion: 1,
        coordenadasGps: '-17.34, -63.25',
        glosa: 'Casa blanca portón rejas',
        fotoBytes: Uint8List(0),
      );

      expect(resultVacio, false);
      expect(notifier.state.errorMessage, 'Debe adjuntar una fotografía de evidencia (obligatoria).');
    });

    test('ReconexionNotifier registra exitosamente cuando se proporciona fotografía', () async {
      final fakeRepo = _FakeReconexionRepository();
      final notifier = ReconexionNotifier(fakeRepo);

      final result = await notifier.registrarSolicitud(
        codSocio: '267657',
        idTipoReconexion: 1,
        coordenadasGps: '-17.34, -63.25',
        glosa: 'Casa blanca portón rejas',
        fotoBytes: Uint8List.fromList([1, 2, 3]),
        fotoFilename: 'fachada.jpg',
      );

      expect(result, true);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.ticketEmitido?.idReconexion, 5555);
    });
  });
}
