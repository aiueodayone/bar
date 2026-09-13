import 'dart:async';

/// 広告完全削除(買い切り)の課金アイテムID。
const String kRemoveAdsProductId = 'remove_ads_lifetime';

/// テーマパック(着せ替え)解放(買い切り)の課金アイテムID。
const String kThemePackProductId = 'premium_themes_pack';

/// 「広告完全削除」「テーマパック解放」の買い切り課金を扱うサービス。
///
/// 診断用ビルド: 課金SDK(in_app_purchase)が起動時クラッシュの原因か
/// 切り分けるため、一時的に何もしないダミーにしている。
class PurchaseService {
  final _adsRemovedController = StreamController<bool>.broadcast();
  Stream<bool> get adsRemovedStream => _adsRemovedController.stream;

  final _themesUnlockedController = StreamController<bool>.broadcast();
  Stream<bool> get themesUnlockedStream => _themesUnlockedController.stream;

  Object? get removeAdsProduct => null;
  Object? get themePackProduct => null;

  Future<void> initialize() async {}

  Future<void> buyRemoveAds() async {}

  Future<void> buyThemePack() async {}

  Future<void> restorePurchases() async {}

  void dispose() {
    _adsRemovedController.close();
    _themesUnlockedController.close();
  }
}
