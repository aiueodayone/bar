import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'settings_service.dart';

/// 広告完全削除(買い切り)の課金アイテムID。
/// Google Play Console でアプリ内アイテムとしてこの ID を登録すること。
const String kRemoveAdsProductId = 'remove_ads_lifetime';

/// 「広告完全削除」の買い切り課金を扱うサービス。
///
/// バナー広告のみで運用し、価値を感じたユーザーが買い切りで広告を消せる
/// フリーミアムモデルを想定している。
class PurchaseService {
  PurchaseService({SettingsService? settingsService})
      : _settingsService = settingsService ?? SettingsService();

  final SettingsService _settingsService;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final _adsRemovedController = StreamController<bool>.broadcast();
  Stream<bool> get adsRemovedStream => _adsRemovedController.stream;

  ProductDetails? _removeAdsProduct;
  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object _) {},
    );

    final response =
        await _iap.queryProductDetails({kRemoveAdsProductId});
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
  }

  Future<void> buyRemoveAds() async {
    final product = _removeAdsProduct;
    if (product == null) return;
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.productID != kRemoveAdsProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _settingsService.setAdsRemoved(true);
          _adsRemovedController.add(true);
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _adsRemovedController.close();
  }
}
