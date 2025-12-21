import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('en');
  bool _isAuthenticated = false;
  final ApiService _apiService = ApiService();

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isAuthenticated => _isAuthenticated;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isAmharic => _locale.languageCode == 'am';

  AppProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    _isAuthenticated = token != null;
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    final success = await _apiService.login(phone, password);
    if (success) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return success;
  }

  Future<bool> register(String phone, String password) async {
    return await _apiService.register(phone, password);
  }

  Future<void> logout() async {
    await _apiService.logout();
    _isAuthenticated = false;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void toggleLanguage() {
    _locale = _locale.languageCode == 'en' ? const Locale('am') : const Locale('en');
    notifyListeners();
  }
}
