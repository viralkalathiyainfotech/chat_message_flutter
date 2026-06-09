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

  Future<void> saveTokens({required String token, required String refreshToken}) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_refreshTokenKey, refreshToken);
  }

  String? get token => _prefs.getString(_tokenKey);
  String? get refreshToken => _prefs.getString(_refreshTokenKey);
  
  String? getToken() => token;
  String? getUserId() => _prefs.getString('user_id'); // We'll assume user_id is saved during login
  
  String? getString(String key) => _prefs.getString(key);
  Future<void> saveString(String key, String value) async => await _prefs.setString(key, value);

  Future<void> clearTokens() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshTokenKey);
  }

  bool get isLoggedIn => token != null;

  Future<void> saveThemeMode(bool isDarkMode) async {
    await _prefs.setBool(_isDarkModeKey, isDarkMode);
  }

  bool? get isDarkMode => _prefs.getBool(_isDarkModeKey);
}
