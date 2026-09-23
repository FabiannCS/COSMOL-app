import 'package:flutter/foundation.dart';

/// Configuración global de entorno y URLs de conexión.
class AppConfig {
  AppConfig._();

  /// URL Base oficial de producción en el servidor de COSMOL (Puerto 443 estándar con SSL)
  static const String _productionBaseUrl = 'https://chatbot.cosmol.com.bo/api/v1';

  /// Detecta la URL base según la plataforma o entorno de ejecución
  static String get baseUrl {
    // 1. Sobreescritura manual para pruebas específicas en desarrollo:
    // flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000/api/v1
    const String customBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }

    // 2. Si se fuerza explícitamente modo emulador Android:
    const bool isEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
    if (isEmulator) {
      return 'http://10.0.2.2:8000/api/v1';
    }

    // 3. Web local en desarrollo:
    if (kIsWeb && kDebugMode) {
      return 'http://localhost:8000/api/v1';
    }

    // 4. DESTINO PREDETERMINADO OFICIAL (Dispositivos físicos Android / iOS y builds de producción):
    return _productionBaseUrl;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
