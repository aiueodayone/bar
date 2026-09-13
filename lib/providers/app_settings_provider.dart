import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';

/// 広告表示・課金状態・テーマ(着せ替え)などアプリ全体の設定を管理する。
class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider({
    SettingsService? settingsService,
    PurchaseService? purchaseService,
  })  : _settingsService = settingsService ?? SettingsService(),
        _purchaseService = purchaseService ?? PurchaseService();

  final SettingsService _settingsService;
  final PurchaseService _purchaseService;

  bool _adsRemoved = false;
  bool get adsRemoved => _adsRemoved;

  bool get canPurchase => _purchaseService.removeAdsProduct != null;
  String? get removeAdsPrice => _purchaseService.removeAdsProduct?.price;

  bool _themesUnlocked = false;
  bool get themesUnlocked => _themesUnlocked;

  bool get canPurchaseThemePack => _purchaseService.themePackProduct != null;
  String? get themePackPrice => _purchaseService.themePackProduct?.price;

  AppTheme _currentTheme = findThemeById(kDefaultThemeId);
  AppTheme get currentTheme => _currentTheme;

  Future<void> init() async {
    _adsRemoved = await _settingsService.isAdsRemoved();
    _themesUnlocked = await _settingsService.isThemesUnlocked();
    final themeId = await _settingsService.getSelectedThemeId();
    _currentTheme = findThemeById(themeId);
    notifyListeners();

    await _purchaseService.initialize();
    _purchaseService.adsRemovedStream.listen((removed) {
      _adsRemoved = removed;
      notifyListeners();
    });
    _purchaseService.themesUnlockedStream.listen((unlocked) {
      _themesUnlocked = unlocked;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> buyRemoveAds() => _purchaseService.buyRemoveAds();

  Future<void> buyThemePack() => _purchaseService.buyThemePack();

  Future<void> restorePurchases() => _purchaseService.restorePurchases();

  /// テーマを選択する。無料テーマ、またはテーマパック購入済みの場合のみ反映される。
  Future<void> selectTheme(AppTheme theme) async {
    if (theme.isPremium && !_themesUnlocked) return;
    _currentTheme = theme;
    await _settingsService.setSelectedThemeId(theme.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }
}
