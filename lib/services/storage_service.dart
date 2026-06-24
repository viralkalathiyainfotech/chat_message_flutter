import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService extends GetxService {
  late SharedPreferences _prefs;

  Future<StorageService> init() async {
    _prefs = await SharedPreferences.getInstance();
    return this;
  }

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _userIdKey = 'user_id';
  static const List<String> _userScopedKeys = [
    _tokenKey,
    _refreshTokenKey,
    _userIdKey,
    'last_synced_message_event_id',
    'delivered_message_ids',
    'pending_delivered_message_ids',
  ];

  Future<void> saveTokens({required String token, required String refreshToken}) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_refreshTokenKey, refreshToken);
  }

  String? get token => _prefs.getString(_tokenKey);
  String? get refreshToken => _prefs.getString(_refreshTokenKey);
  
  String? getToken() => token;
  
  String? getUserId() {
    String? id = _prefs.getString(_userIdKey);
    if (id == null && token != null) {
      try {
        final parts = token!.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final map = jsonDecode(decoded);
          id = map['id'] ?? map['_id'];
          if (id != null) {
            _prefs.setString(_userIdKey, id);
          }
        }
      } catch (e) {
        Get.log('Failed to decode user_id from token: $e');
      }
    }
    return id;
  }
  
  String? getString(String key) => _prefs.getString(key);
  Future<void> saveString(String key, String value) async => await _prefs.setString(key, value);
  bool getBool(String key, {bool defaultValue = false}) => _prefs.getBool(key) ?? defaultValue;
  Future<void> setBool(String key, bool value) async => await _prefs.setBool(key, value);
  Future<void> remove(String key) async => await _prefs.remove(key);

  Future<void> clearTokens() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_userIdKey);
  }

  Future<void> clearUserScopedPreferences() async {
    for (final key in _userScopedKeys) {
      await _prefs.remove(key);
    }
  }

  bool get isLoggedIn => token != null;

  Future<void> saveThemeMode(bool isDarkMode) async {
    await _prefs.setBool(_isDarkModeKey, isDarkMode);
  }

  bool? get isDarkMode => _prefs.getBool(_isDarkModeKey);
}
