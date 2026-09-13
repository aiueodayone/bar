import 'package:flutter/material.dart';

/// 画面下部に表示するバナー広告。
///
/// 診断用ビルド: 広告SDK(google_mobile_ads)が起動時クラッシュの原因か
/// 切り分けるため、一時的に何も表示しないダミーにしている。
class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
