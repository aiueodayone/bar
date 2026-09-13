import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/genre_repository.dart';
import '../data/memo_repository.dart';
import '../providers/app_settings_provider.dart';
import '../services/export_service.dart';
import 'privacy_info_screen.dart';
import 'template_management_screen.dart';
import 'theme_selection_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportAllMemos(BuildContext context) async {
    final memos = await MemoRepository().fetchMemos();
    final genres = await GenreRepository().fetchGenres();
    if (!context.mounted) return;
    if (memos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポートするメモがありません')),
      );
      return;
    }
    await ExportService().exportAllMemos(memos, genres);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.palette_outlined,
              color: settings.currentTheme.seedColor,
            ),
            title: const Text('テーマ(着せ替え)'),
            subtitle: Text(
              settings.themesUnlocked ? '${settings.currentTheme.name} を使用中' : '無料テーマ + 買い切りで追加テーマを解放',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeSelectionScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('議事録テンプレートを管理'),
            subtitle: const Text('プリセットの確認・カスタムテンプレートの作成'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TemplateManagementScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('全メモをエクスポート'),
            subtitle: const Text('ジャンルごとにまとめたテキストファイルを書き出して共有します'),
            onTap: () => _exportAllMemos(context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('データの取り扱いについて'),
            subtitle: const Text('録音データや文字起こしが外部に送信されるかどうか'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyInfoScreen()),
            ),
          ),
          const Divider(),
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
              SizedBox(height: 16),
              Text(
                'オフライン音声認識には Vosk(alphacephei.com)を使用しています。'
                '(Apache License 2.0)',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                '使用しているすべてのオープンソースライブラリのライセンスは'
                '「ライセンスを表示」から確認できます。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
