import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuración global de entorno y URLs de conexión.
class AppConfig {
  AppConfig._();

  /// Detecta la URL base según la plataforma o variables de compilación (--dart-define).
  static String get baseUrl {
    // 1. Inyección de URL completa (ej. --dart-define=API_URL=http://192.168.11.61:8000/api/v1)
    const String customApiUrl = String.fromEnvironment('API_URL');
    if (customApiUrl.isNotEmpty) {
      return customApiUrl;
    }

    // 2. Inyección solo de la IP local de Wi-Fi (ej. --dart-define=BACKEND_IP=192.168.11.61)
    const String customBackendIp = String.fromEnvironment('BACKEND_IP');
    if (customBackendIp.isNotEmpty) {
      return 'http://$customBackendIp:8000/api/v1';
    }

    // 3. Web
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }

    // 4. Android
    if (Platform.isAndroid) {
      // Si se usa emulador Android sin reverse port
      const bool isEmulator = bool.fromEnvironment('EMULATOR', defaultValue: false);
      if (isEmulator) {
        return 'http://10.0.2.2:8000/api/v1';
      }
      // Por defecto para depuración local por cable (adb reverse)
      return 'http://localhost:8000/api/v1';
    }

    return 'http://localhost:8000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
}
