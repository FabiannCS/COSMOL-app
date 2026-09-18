import 'package:dio/dio.dart';
import '../services/device_service.dart';

/// Interceptor que inyecta automáticamente la cabecera HTTP `X-Device-Id`
class DeviceInterceptor extends Interceptor {
  final DeviceService deviceService;

  DeviceInterceptor({required this.deviceService});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final deviceInfo = await deviceService.getDeviceInfo();
      options.headers['X-Device-Id'] = deviceInfo.deviceId;
    } catch (_) {
      // Si falla la lectura del hardware, continua con la solicitud
    }
    handler.next(options);
  }
}
