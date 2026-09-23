import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuración global de entorno y URLs de conexión.
class AppConfig {
  AppConfig._();

  /// URL remota del backend institucional desplegado en el servidor
  static const String remoteBaseUrl = 'https://chatbot.cosmol.com.bo:8083/api/v1';

  /// Detecta la URL base según la plataforma o entorno de ejecución
  static String get baseUrl {
    // 1. Si se define explícitamente en tiempo de compilación o ejecución:
    // flutter run --dart-define=API_BASE_URL=https://chatbot.cosmol.com.bo:8083/api/v1
    const String customBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }

    // 2. En modo Release (compilación de APK para distribución/despliegue):
    // Se conecta directamente al servidor remoto sin necesidad de cables ni localhost.
    if (kReleaseMode) {
      return remoteBaseUrl;
    }

    // 3. Si en modo Debug se indica expresamente usar el servidor remoto:
    // flutter run --dart-define=USE_REMOTE=true
    const bool useRemote = bool.fromEnvironment('USE_REMOTE', defaultValue: false);
    if (useRemote) {
      return remoteBaseUrl;
    }

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
