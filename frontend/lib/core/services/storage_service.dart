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

  StorageService(this._secureStorage);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Tokens de Autenticación ---
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    final token = await _secureStorage.read(key: _keyAccessToken);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<String?> getRefreshToken() async {
    final token = await _secureStorage.read(key: _keyRefreshToken);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<void> clearAuthData() async {
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
    await _secureStorage.write(key: _keyCodSocio, value: codSocio);
  }

  Future<String?> getActiveCodSocio() async {
    final codSocio = await _secureStorage.read(key: _keyCodSocio);
    if (codSocio == null || codSocio.trim().isEmpty) return null;
    return codSocio.trim();
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
