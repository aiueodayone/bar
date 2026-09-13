import 'package:shared_preferences/shared_preferences.dart';

/// アプリ全体の簡易設定(広告解除フラグなど)を扱うサービス。
class SettingsService {
  static const String _keyAdsRemoved = 'ads_removed';

  Future<bool> isAdsRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAdsRemoved) ?? false;
  }

  Future<void> setAdsRemoved(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAdsRemoved, value);
  }
}
