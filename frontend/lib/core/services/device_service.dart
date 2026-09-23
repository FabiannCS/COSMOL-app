import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';

final deviceServiceProvider = Provider<DeviceService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return DeviceService(storageService);
});

class DeviceInfoResult {
  final String deviceId;
  final String deviceModel;

  DeviceInfoResult({
    required this.deviceId,
    required this.deviceModel,
  });
}

/// Servicio encubridor de hardware y plataforma para obtener el `X-Device-Id`
/// y el nombre/modelo del equipo.
class DeviceService {
  final StorageService _storageService;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  DeviceService(this._storageService);

  Future<DeviceInfoResult> getDeviceInfo() async {
    // 1. Obtener o generar Device ID único
    String? deviceId = await _storageService.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _storageService.saveDeviceId(deviceId);
    }

    // 2. Obtener modelo del dispositivo según la plataforma
    String deviceModel = 'Desconocido';

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        deviceModel = 'Navegador Web (${webInfo.browserName.name})';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceModel = '${iosInfo.name} (${iosInfo.utsname.machine})';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        deviceModel = 'Windows PC (${windowsInfo.computerName})';
      }
    } catch (_) {
      deviceModel = 'Dispositivo COSMOL App';
    }

    return DeviceInfoResult(
      deviceId: deviceId,
      deviceModel: deviceModel,
    );
  }
}
