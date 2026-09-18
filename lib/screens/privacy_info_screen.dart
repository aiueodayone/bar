import 'package:flutter/material.dart';

/// 音声データ・メモの取り扱いについて説明する画面。
class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('データの取り扱いについて')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            icon: Icons.mic_outlined,
            title: '録音した音声データについて',
            body:
                '録音した音声ファイルは、この端末の中にのみ保存されます。\n'
                'メモの内容や録音データが、開発者を含む外部のサーバーへ自動的に'
                '送信されることはありません。',
          ),
          _Section(
            icon: Icons.subtitles_outlined,
            title: '文字起こし(音声認識)について',
            body:
                '文字起こしは端末内で完結するオフライン処理(Vosk)で行われます。\n'
                'あなたが話した内容が外部のAIサービスに送信されたり、AIの学習'
                'データとして利用されたりすることはありません。\n\n'
                '初回の文字起こし時のみ、音声認識モデルのファイルを受け取るために '
                'alphacephei.com(Voskの配布元)へアクセスしますが、これは'
                'モデルを「受け取るだけ」の一方向の通信です。あなたの音声や'
                'メモの内容がこの通信で送信されることはありません。',
          ),
          _Section(
            icon: Icons.backup_outlined,
            title: 'バックアップについて',
            body:
                'バックアップファイルは、あなたが「保存先を選ぶ」ダイアログで'
                '指定した場所(Googleドライブや端末のストレージなど)に保存'
                'されるだけで、開発者を含む外部のサーバーへ自動的に送信される'
                'ことはありません。\n\n'
                'ファイルの中身はアプリに組み込まれた鍵で自動的に暗号化されて'
                'おり、パスワードなどの入力は不要です。ただし、これはクラウド'
                'ストレージなどに置いた際に他人が偶然中身を読めてしまうことを'
                '防ぐための軽い保護であり、アプリ自体を解析するような本格的な'
                '攻撃に対する秘匿性までは保証していません。',
          ),
          _Section(
            icon: Icons.lock_outline,
            title: 'アプリロックについて',
            body:
                '起動時のパスワードや、復旧用の秘密の質問の答えは、そのままの'
                '文字列としては保存されません。復元できない形に変換(ハッシュ化)'
                'した上で端末内にのみ保存しており、外部に送信されることも'
                'ありません。',
          ),
          _Section(
            icon: Icons.ads_click_outlined,
            title: '広告・課金について',
            body:
                '広告表示(Google AdMob)や購入処理(Google Play)には、その'
                '機能に必要な最小限の情報(広告ID等)がGoogleに渡ることが'
                'あります。これらはメモの内容や録音データとは一切関係ありません。',
          ),
          _Section(
            icon: Icons.visibility_off_outlined,
            title: 'それ以外のトラッキングについて',
            body: 'このアプリには、上記以外のアクセス解析・行動トラッキング機能は組み込まれていません。',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}
