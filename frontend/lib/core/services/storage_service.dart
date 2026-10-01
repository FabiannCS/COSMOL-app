import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});

/// Servicio unificado de persistencia local:
/// - Seguro (`FlutterSecureStorage`) para tokens JWT e información confidencial.
/// - Preferencias (`SharedPreferences`) para configuraciones generales.
class StorageService {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  static const String _keyAccessToken = 'jwt_access_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyCodSocio = 'active_cod_socio';
  static const String _keyDeviceId = 'device_id_uuid';

  // Caché en memoria de acceso ultra rápido (0ms) para evitar carreras con el Keystore nativo
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedCodSocio;

  StorageService(this._secureStorage);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Tokens de Autenticación ---
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken.trim();
    _cachedRefreshToken = refreshToken.trim();
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    final token = await _secureStorage.read(key: _keyAccessToken);
    if (token == null || token.trim().isEmpty) return null;
    _cachedAccessToken = token.trim();
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    final token = await _secureStorage.read(key: _keyRefreshToken);
    if (token == null || token.trim().isEmpty) return null;
    _cachedRefreshToken = token.trim();
    return _cachedRefreshToken;
  }

  Future<void> clearAuthData() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedCodSocio = null;
    try {
      await _secureStorage.write(key: _keyAccessToken, value: '');
      await _secureStorage.write(key: _keyRefreshToken, value: '');
      await _secureStorage.write(key: _keyCodSocio, value: '');
      await _secureStorage.delete(key: _keyAccessToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyCodSocio);
    } catch (_) {}
  }

  // --- Código de Socio Principal ---
  Future<void> saveActiveCodSocio(String codSocio) async {
    _cachedCodSocio = codSocio.trim();
    await _secureStorage.write(key: _keyCodSocio, value: codSocio);
  }

  Future<String?> getActiveCodSocio() async {
    if (_cachedCodSocio != null && _cachedCodSocio!.isNotEmpty) {
      return _cachedCodSocio;
    }
    final codSocio = await _secureStorage.read(key: _keyCodSocio);
    if (codSocio == null || codSocio.trim().isEmpty) return null;
    _cachedCodSocio = codSocio.trim();
    return _cachedCodSocio;
  }

  // --- Device ID Persistente ---
  Future<void> saveDeviceId(String deviceId) async {
    await _secureStorage.write(key: _keyDeviceId, value: deviceId);
  }

  Future<String?> getDeviceId() async {
    return await _secureStorage.read(key: _keyDeviceId);
  }

  // --- General Preferences ---
  Future<void> setBool(String key, bool value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }
}
