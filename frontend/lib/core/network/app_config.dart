import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuración global de entorno y URLs de conexión.
class AppConfig {
  AppConfig._();

  /// Detecta la URL base según la plataforma o entorno de ejecución
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }

    if (Platform.isAndroid) {
      // 10.0.2.2 es la IP de loopback del emulador Android para acceder al host localhost.
      // Si se prueba en dispositivo físico con `adb reverse tcp:8000 tcp:8000`, puede usar localhost:8000.
      const bool isPhysicalUsbDevice = bool.fromEnvironment('PHYSICAL_DEVICE', defaultValue: false);
      if (isPhysicalUsbDevice) {
        return 'http://localhost:8000/api/v1';
      }
      return 'http://10.0.2.2:8000/api/v1';
    }

    return 'http://localhost:8000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
}
