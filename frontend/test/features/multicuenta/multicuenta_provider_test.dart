import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/multicuenta/domain/repositories/multicuenta_repository.dart';
import 'package:cosmol_app/features/multicuenta/presentation/providers/multicuenta_provider.dart';
import 'package:cosmol_app/core/services/storage_service.dart';

class MockMulticuentaRepository implements MulticuentaRepository {
  final List<SuministroModel> mockSuministros;

  MockMulticuentaRepository({required this.mockSuministros});

  @override
  Future<List<SuministroModel>> listarSuministros() async {
    return mockSuministros;
  }

  @override
  Future<SuministroModel> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) async {
    final rol = ciOMedidor != null && ciOMedidor.isNotEmpty
        ? 'TITULAR'
        : 'CONSULTA_PAGO';
    return SuministroModel(
      id: 'mock-id-2',
      codSocio: codSocio,
      alias: alias,
      rol: rol,
      esSuministroPrincipal: false,
    );
  }
}

class FakeStorageService implements StorageService {
  String? activeCodSocio;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveActiveCodSocio(String codSocio) async {
    activeCodSocio = codSocio;
  }

  @override
  Future<String?> getActiveCodSocio() async => activeCodSocio;

  @override
  Future<void> clearAuthData() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}

  @override
  Future<void> saveDeviceId(String deviceId) async {}

  @override
  Future<String?> getDeviceId() async => null;

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
}

void main() {
  group('MulticuentaNotifier Tests', () {
    late MockMulticuentaRepository mockRepo;
    late FakeStorageService mockStorage;

    final suministroInitial = const SuministroModel(
      id: 'mock-id-1',
      codSocio: '104523',
      alias: 'Casa Principal',
      rol: 'TITULAR',
      esSuministroPrincipal: true,
    );

    setUp(() {
      mockRepo = MockMulticuentaRepository(mockSuministros: [suministroInitial]);
      mockStorage = FakeStorageService();
    });

    test('Inicialización de MulticuentaNotifier asigna suministros iniciales', () {
      final notifier = MulticuentaNotifier(
        repository: mockRepo,
        storageService: mockStorage,
        initialSuministros: [suministroInitial],
        initialCodSocio: '104523',
      );

      expect(notifier.state.suministros.length, 1);
      expect(notifier.state.activeSuministro?.codSocio, '104523');
      expect(notifier.state.activeSuministro?.rol, 'TITULAR');
    });

    test('Vincular nuevo suministro actualiza la lista y el activo', () async {
      final notifier = MulticuentaNotifier(
        repository: mockRepo,
        storageService: mockStorage,
        initialSuministros: [suministroInitial],
        initialCodSocio: '104523',
      );

      final result = await notifier.vincularSuministro(
        codSocio: '104524',
        ciOMedidor: null,
        alias: 'Depto Alquiler',
      );

      expect(result, true);
      expect(notifier.state.suministros.length, 2);
      expect(notifier.state.activeSuministro?.codSocio, '104524');
      expect(notifier.state.activeSuministro?.rol, 'CONSULTA_PAGO');
      expect(mockStorage.activeCodSocio, '104524');
    });

    test('Seleccionar suministro cambia el estado activo', () async {
      final nuevoSuministro = const SuministroModel(
        id: 'mock-id-2',
        codSocio: '104524',
        alias: 'Depto Alquiler',
        rol: 'CONSULTA_PAGO',
        esSuministroPrincipal: false,
      );

      final notifier = MulticuentaNotifier(
        repository: mockRepo,
        storageService: mockStorage,
        initialSuministros: [suministroInitial, nuevoSuministro],
        initialCodSocio: '104523',
      );

      await notifier.seleccionarSuministro(nuevoSuministro);

      expect(notifier.state.activeSuministro?.codSocio, '104524');
      expect(mockStorage.activeCodSocio, '104524');
    });
  });
}
