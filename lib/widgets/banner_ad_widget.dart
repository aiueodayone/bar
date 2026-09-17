import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google 公式のテスト用バナー広告ユニットID。
/// ストア公開前に AdMob 管理画面で取得した本番のユニットIDに置き換えること。
const String kBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

/// 画面下部に表示するバナー広告。
/// 広告解除済みの場合は呼び出し側でそもそも生成しない想定。
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: kBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    // 広告の読み込み前後で高さが 0 ⇔ 広告サイズに切り替わると、その上に
    // 固定表示している録音ボタンなどが読み込み完了の瞬間にガクッと
    // 動いてしまう。読み込み中も広告と同じ高さの領域を常に確保しておく
    // ことで、そのレイアウトのずれを防ぐ。
    return SafeArea(
      top: false,
      child: SizedBox(
        width: AdSize.banner.width.toDouble(),
        height: AdSize.banner.height.toDouble(),
        child: (ad != null && _isLoaded) ? AdWidget(ad: ad) : null,
      ),
    );
  }
}
