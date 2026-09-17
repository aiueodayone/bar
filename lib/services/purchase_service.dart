import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'settings_service.dart';

/// 広告完全削除(買い切り)の課金アイテムID。
/// Google Play Console でアプリ内アイテムとしてこの ID を登録すること。
const String kRemoveAdsProductId = 'remove_ads_lifetime';

/// テーマパック(着せ替え)解放(買い切り)の課金アイテムID。
/// Google Play Console でアプリ内アイテムとしてこの ID を登録すること。
const String kThemePackProductId = 'premium_themes_pack';

/// 「広告完全削除」「テーマパック解放」の買い切り課金を扱うサービス。
///
/// バナー広告のみで運用し、価値を感じたユーザーが買い切りで広告を消したり
/// 追加のカラーテーマを使えるようにしたりするフリーミアムモデルを想定している。
class PurchaseService {
  PurchaseService({SettingsService? settingsService})
    : _settingsService = settingsService ?? SettingsService();

  final SettingsService _settingsService;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final _adsRemovedController = StreamController<bool>.broadcast();
  Stream<bool> get adsRemovedStream => _adsRemovedController.stream;

  final _themesUnlockedController = StreamController<bool>.broadcast();
  Stream<bool> get themesUnlockedStream => _themesUnlockedController.stream;

  ProductDetails? _removeAdsProduct;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  ProductDetails? _themePackProduct;
  ProductDetails? get themePackProduct => _themePackProduct;

  Future<void> initialize() async {
    // Play Billing が使えない端末(Playサービス非搭載など)でもアプリ本体の
    // 起動を妨げないよう、課金関連の失敗はすべてここで吸収する。
    try {
      final available = await _iap.isAvailable();
      if (!available) return;

      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object _) {},
      );

      final response = await _iap.queryProductDetails({
        kRemoveAdsProductId,
        kThemePackProductId,
      });
      for (final product in response.productDetails) {
        if (product.id == kRemoveAdsProductId) {
          _removeAdsProduct = product;
        } else if (product.id == kThemePackProductId) {
          _themePackProduct = product;
        }
      }
    } catch (_) {
      // 課金機能なしで続行
    }
  }

  Future<void> buyRemoveAds() => _buy(_removeAdsProduct);

  Future<void> buyThemePack() => _buy(_themePackProduct);

  Future<void> _buy(ProductDetails? product) async {
    if (product == null) return;
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final unlocked =
          purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored;

      if (unlocked && purchase.productID == kRemoveAdsProductId) {
        await _settingsService.setAdsRemoved(true);
        _adsRemovedController.add(true);
      } else if (unlocked && purchase.productID == kThemePackProductId) {
        await _settingsService.setThemesUnlocked(true);
        _themesUnlockedController.add(true);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _adsRemovedController.close();
    _themesUnlockedController.close();
  }
}
