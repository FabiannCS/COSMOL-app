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
    return await _secureStorage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _keyRefreshToken);
  }

  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await _secureStorage.delete(key: _keyCodSocio);
  }

  // --- Código de Socio Principal ---
  Future<void> saveActiveCodSocio(String codSocio) async {
    await _secureStorage.write(key: _keyCodSocio, value: codSocio);
  }

  Future<String?> getActiveCodSocio() async {
    return await _secureStorage.read(key: _keyCodSocio);
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
