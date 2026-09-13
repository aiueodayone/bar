import 'package:flutter/material.dart';

import '../services/purchase_service.dart';
import '../services/settings_service.dart';

/// 広告表示・課金状態などアプリ全体の設定を管理する。
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

  Future<void> init() async {
    _adsRemoved = await _settingsService.isAdsRemoved();
    notifyListeners();

    await _purchaseService.initialize();
    _purchaseService.adsRemovedStream.listen((removed) {
      _adsRemoved = removed;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> buyRemoveAds() => _purchaseService.buyRemoveAds();

  Future<void> restorePurchases() => _purchaseService.restorePurchases();

  @override
  void dispose() {
    _purchaseService.dispose();
    super.dispose();
  }
}
