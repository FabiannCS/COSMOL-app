import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cosmol_app/core/network/auth_interceptor.dart';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/core/services/device_service.dart';

class FakeStorageService implements StorageService {
  String? accessToken;
  String? refreshToken;
  String? activeCodSocio;
  String? deviceId;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> clearAuthData() async {
    accessToken = null;
    refreshToken = null;
    activeCodSocio = null;
  }

  @override
  Future<void> saveActiveCodSocio(String codSocio) async {
    activeCodSocio = codSocio;
  }

  @override
  Future<String?> getActiveCodSocio() async => activeCodSocio;

  @override
  Future<void> saveDeviceId(String deviceId) async {
    this.deviceId = deviceId;
  }

  @override
  Future<String?> getDeviceId() async => deviceId;

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
}

class FakeDeviceService implements DeviceService {
  @override
  Future<DeviceInfoResult> getDeviceInfo() async {
    return DeviceInfoResult(
      deviceId: 'fake-device-id',
      deviceModel: 'Fake Device',
    );
  }
}

class FakeErrorInterceptorHandler extends ErrorInterceptorHandler {
  DioException? rejectedError;
  DioException? nextError;

  @override
  void reject(DioException error, [bool callCompleter = true]) {
    rejectedError = error;
  }

  @override
  void next(DioException error) {
    nextError = error;
  }
}

void main() {
  group('AuthInterceptor Tests', () {
    late FakeStorageService storageService;
    late FakeDeviceService deviceService;
    late AuthInterceptor interceptor;

    setUp(() {
      storageService = FakeStorageService();
      deviceService = FakeDeviceService();
      interceptor = AuthInterceptor(
        storageService: storageService,
        deviceService: deviceService,
        refreshDio: Dio(),
      );
    });

    test('onRequest injects Bearer token if token exists in StorageService', () async {
      storageService.accessToken = 'test-bearer-token';
      final options = RequestOptions(path: '/profile');
      final handler = RequestInterceptorHandler();

      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer test-bearer-token');
    });

    test('onRequest does not set Authorization header if token is null', () async {
      storageService.accessToken = null;
      final options = RequestOptions(path: '/profile');
      final handler = RequestInterceptorHandler();

      await interceptor.onRequest(options, handler);

      expect(options.headers.containsKey('Authorization'), false);
    });

    test('onError handles SESSION_REVOKED_NEW_DEVICE by clearing auth data and invoking callback', () async {
      storageService.accessToken = 'old-token';
      bool sessionRevokedCalled = false;

      interceptor.onSessionRevoked = () {
        sessionRevokedCalled = true;
      };

      final dioError = DioException(
        requestOptions: RequestOptions(path: '/user'),
        response: Response(
          requestOptions: RequestOptions(path: '/user'),
          statusCode: 401,
          data: {
            'success': false,
            'error': {
              'code': 'SESSION_REVOKED_NEW_DEVICE',
              'message': 'Sesión revocada.',
            },
          },
        ),
      );

      final handler = FakeErrorInterceptorHandler();
      await interceptor.onError(dioError, handler);

      expect(sessionRevokedCalled, true);
      expect(storageService.accessToken, isNull);
      expect(handler.rejectedError, isNotNull);
    });
  });
}
