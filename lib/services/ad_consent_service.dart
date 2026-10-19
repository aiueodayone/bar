import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 広告を出す前に、GDPR 等で同意取得が必要な地域(EU・英国など)の
/// 利用者から Google の User Messaging Platform(UMP)で同意を得る。
///
/// 同意が不要な地域(日本など)では UMP が即座に「不要」と返すので、
/// 従来どおりすぐ広告が出る。必要な地域では同意画面が閉じられるまで
/// 広告をリクエストしない([canRequestAds] が false のまま)。
///
/// 同意メッセージ自体は AdMob 管理画面(プライバシーとメッセージ)で
/// 作成・公開しておく必要がある。未作成だと同意が必要な地域では
/// 広告が出ないだけで、アプリの他の機能には影響しない。
class AdConsentService {
  AdConsentService._();

  static final AdConsentService instance = AdConsentService._();

  /// 広告をリクエストしてよい状態なら true。BannerAdWidget はこれが
  /// true になるのを待ってから広告を読み込む。
  final ValueNotifier<bool> canRequestAds = ValueNotifier<bool>(false);

  /// 設定画面に「広告のプライバシー設定」(同意内容の変更)を出すべきか。
  /// 同意取得が必要な地域の利用者にのみ true になる(Google の要件)。
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier<bool>(false);

  bool _mobileAdsInitialized = false;

  /// 起動時に一度呼ぶ。前回の同意状態があればまず即座に広告を許可し、
  /// その後で最新の同意情報を取得して必要なら同意画面を出す
  /// (Google が推奨する「前回の同意で先に広告を出しつつ更新する」手順)。
  Future<void> initialize() async {
    await _refresh();

    final completer = Completer<void>();
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((_) async {
            await _refresh();
            finish();
          });
        },
        (_) async {
          // オフライン・同意メッセージ未作成など。前回の同意状態のまま続行。
          await _refresh();
          finish();
        },
      );
    } catch (_) {
      finish();
    }
    return completer.future;
  }

  /// 設定画面から同意内容を見直すための画面を開く。
  Future<void> showPrivacyOptionsForm() async {
    final completer = Completer<void>();
    try {
      await ConsentForm.showPrivacyOptionsForm((_) async {
        await _refresh();
        if (!completer.isCompleted) completer.complete();
      });
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  Future<void> _refresh() async {
    try {
      final allowed = await ConsentInformation.instance.canRequestAds();
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired.value =
          status == PrivacyOptionsRequirementStatus.required;
      if (allowed && !_mobileAdsInitialized) {
        _mobileAdsInitialized = true;
        await MobileAds.instance.initialize();
      }
      canRequestAds.value = allowed;
    } catch (_) {
      // 広告なしで続行(アプリ本体の動作には影響させない)。
    }
  }
}
