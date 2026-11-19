import 'dart:io';
import 'package:flutter/foundation.dart';

/// Configuración global de entorno y URLs de conexión.
class AppConfig {
  AppConfig._();

  /// URL remota del backend institucional desplegado en el servidor.
  static const String remoteBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://chatbot.cosmol.com.bo/api/v1',
  );

  /// URL del servidor de consultas de COSMOL R.L. (informix legado)
  static const String cosmolLegacyUrl = String.fromEnvironment(
    'COSMOL_LEGACY_URL',
    defaultValue: 'http://api.cosmol.com.bo/api-consultas',
  );

  /// Detecta la URL base según la plataforma o entorno de ejecución
  static String get baseUrl {
    // 1. Si se define explícitamente en tiempo de compilación o ejecución:
    const String customBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }

    // 2. Si se indica expresamente usar entorno local de desarrollo:
    // flutter run --dart-define=USE_LOCAL=true
    const bool useLocal = bool.fromEnvironment('USE_LOCAL', defaultValue: false);
    if (useLocal) {
      if (kIsWeb) return 'http://localhost:8000/api/v1';
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
      return 'http://localhost:8000/api/v1';
    }

    // 3. Por defecto en MODO PRODUCCIÓN (Web, Android, iOS): siempre apunta al servidor oficial
    return remoteBaseUrl;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);
}
