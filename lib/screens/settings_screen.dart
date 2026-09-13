import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          if (settings.adsRemoved)
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('広告は削除されています'),
              subtitle: Text('ご購入ありがとうございます'),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('広告を完全に削除(買い切り)'),
              subtitle: Text(
                settings.canPurchase
                    ? '一度の購入で今後ずっと広告が表示されなくなります (${settings.removeAdsPrice ?? ''})'
                    : 'ストア接続を確認できませんでした',
              ),
              trailing: FilledButton(
                onPressed: settings.canPurchase
                    ? () => settings.buyRemoveAds()
                    : null,
                child: const Text('購入'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('購入を復元'),
              onTap: () => settings.restorePurchases(),
            ),
          ],
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'メモ帳',
            applicationVersion: '1.0.0',
            aboutBoxChildren: [
              Text('広告に邪魔されず、音声メモ・文字起こし・ジャンル分類・検索ができるメモアプリです。'),
            ],
          ),
        ],
      ),
    );
  }
}
