import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme.dart';

/// アプリ全体の簡易設定(広告解除フラグなど)を扱うサービス。
class SettingsService {
  static const String _keyAdsRemoved = 'ads_removed';
  static const String _keyOnboardingSeen = 'onboarding_seen';
  static const String _keySelectedThemeId = 'selected_theme_id';
  static const String _keyThemesUnlocked = 'themes_unlocked';
  static const String _keyDarkModeEnabled = 'dark_mode_enabled';

  Future<bool> isAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdsRemoved) ?? false;
  }

  Future<void> setAdsRemoved(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdsRemoved, value);
  }

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingSeen) ?? false;
  }

  Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingSeen, true);
  }

  Future<String> getSelectedThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedThemeId) ?? kDefaultThemeId;
  }

  Future<void> setSelectedThemeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedThemeId, id);
  }

  Future<bool> isThemesUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyThemesUnlocked) ?? false;
  }

  Future<void> setThemesUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThemesUnlocked, value);
  }

  Future<bool> isDarkModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkModeEnabled) ?? false;
  }

  Future<void> setDarkModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkModeEnabled, value);
  }
}
