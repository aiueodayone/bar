import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/genre_repository.dart';
import '../data/memo_repository.dart';
import '../models/app_theme.dart';
import '../providers/app_lock_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/genre_provider.dart';
import '../providers/memo_provider.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../widgets/app_lock_setup_dialog.dart';
import '../widgets/simple_password_prompt_dialog.dart';
import 'privacy_info_screen.dart';
import 'theme_selection_screen.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// バックアップの作成・復元は(特に動画添付を含む場合)ZIP圧縮や
  /// AES-GCM暗号化で数秒かかることがある。何も表示しないと固まって
  /// 見えてしまうため、処理中はこの操作ブロック用ダイアログを出す。
  /// バックボタンでも閉じられないようにし(canPop: false)、必ず
  /// 呼び出し側の navigator.pop() だけで閉じる前提を保証する。
  static void _showBlockingProgressDialog(
    BuildContext context,
    String message,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportAllMemos(BuildContext context) async {
    final memos = await MemoRepository().fetchMemos();
    final genres = await GenreRepository().fetchGenres();
    if (!context.mounted) return;
    if (memos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('エクスポートするメモがありません')));
      return;
    }
    await ExportService().exportAllMemos(memos, genres);
  }

  Future<void> _createBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    _showBlockingProgressDialog(context, 'バックアップを作成しています…');
    try {
      final (bytes, fileName) = await BackupService().createBackupBytes();
      navigator.pop();
      // 共有シートではなく「保存先を選ぶ」ダイアログ(SAF の
      // ACTION_CREATE_DOCUMENT)を使う。ここには Google ドライブや端末の
      // ストレージなど保存先のみが並び、LINE 等のメッセージ/SNSアプリは
      // 選択肢に出てこないため、誤って他人に送ってしまう心配がない。
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'バックアップの保存先を選択',
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (!context.mounted) return;
      if (savedUri != null) {
        messenger.showSnackBar(const SnackBar(content: Text('バックアップを保存しました')));
      }
    } catch (_) {
      navigator.pop();
      if (!context.mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('バックアップの作成に失敗しました')));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'バックアップファイルを選択',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ファイルを選択できませんでした')));
      return;
    }
    if (picked == null) return;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('バックアップから復元しますか?'),
        content: const Text(
          '選択したバックアップの内容を読み込みます。既存のメモは削除されず、'
          '同じメモがあれば上書き、無ければ追加されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final memoProvider = context.read<MemoProvider>();
    final genreProvider = context.read<GenreProvider>();

    _showBlockingProgressDialog(context, 'バックアップから復元しています…');
    try {
      final bytes = await picked.readAsBytes();
      final (memoCount, genreCount) = await BackupService().restoreFromBackup(
        bytes,
      );
      await genreProvider.load();
      await memoProvider.load();
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('メモ $memoCount 件、ジャンル $genreCount 件を復元しました')),
      );
    } on UnsupportedBackupVersionException catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on InvalidBackupFileException catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('復元に失敗しました')));
    }
  }

  Future<void> _enableAppLock(BuildContext context) async {
    final result = await showAppLockSetupDialog(context, title: 'アプリロックを設定');
    if (result == null) return; // キャンセル
    final (mainPassword, secretQuestion, secretAnswer) = result;
    if (!context.mounted) return;
    await context.read<AppLockProvider>().enable(
      mainPassword: mainPassword,
      secretQuestion: secretQuestion,
      secretAnswer: secretAnswer,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('アプリロックを設定しました')));
  }

  Future<void> _disableAppLock(BuildContext context) async {
    final password = await showSimplePasswordPromptDialog(
      context,
      title: 'アプリロックを解除',
      message: '現在のメインパスワードを入力してください。',
      confirmLabel: '解除する',
    );
    if (password == null) return; // キャンセル
    if (!context.mounted) return;
    final provider = context.read<AppLockProvider>();
    final ok = await provider.verifyMainPassword(password);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('パスワードが正しくありません')));
      return;
    }
    await provider.disable();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('アプリロックを解除しました')));
  }

  Future<void> _changeAppLockPassword(BuildContext context) async {
    final currentPassword = await showSimplePasswordPromptDialog(
      context,
      title: 'パスワードの変更',
      message: '現在のメインパスワードを入力してください。',
      confirmLabel: '次へ',
    );
    if (currentPassword == null) return; // キャンセル

    if (!context.mounted) return;
    final provider = context.read<AppLockProvider>();
    final currentOk = await provider.verifyMainPassword(currentPassword);
    if (!context.mounted) return;
    if (!currentOk) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('パスワードが正しくありません')));
      return;
    }

    final result = await showAppLockSetupDialog(context, title: '新しいパスワードを設定');
    if (result == null) return; // キャンセル
    final (newMainPassword, newSecretQuestion, newSecretAnswer) = result;

    if (!context.mounted) return;
    final changed = await context.read<AppLockProvider>().changePassword(
      currentMainPassword: currentPassword,
      newMainPassword: newMainPassword,
      newSecretQuestion: newSecretQuestion,
      newSecretAnswer: newSecretAnswer,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(changed ? 'パスワードを変更しました' : 'パスワードの変更に失敗しました')),
    );
  }

  Future<void> _restorePurchases(BuildContext context) async {
    final settings = context.read<AppSettingsProvider>();
    await settings.restorePurchases();
    // タップしても何も起きなかったように見えないよう、確認自体は完了した
    // ことをフィードバックする(該当する購入があれば、このあと画面上の
    // 「広告は削除されています」等の表示が反応的に切り替わる)。
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('購入情報を確認しました')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final appLock = context.watch<AppLockProvider>();

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
              kAppThemes.any((t) => t.isPremium) && !settings.themesUnlocked
                  ? '無料テーマ + 買い切りで追加テーマを解放'
                  : '${settings.currentTheme.name} を使用中',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeSelectionScreen()),
            ),
          ),
          SwitchListTile(
            secondary: Icon(
              settings.darkModeEnabled
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            title: const Text('ダークモード'),
            subtitle: Text(settings.darkModeEnabled ? '黒背景で表示中' : '白背景で表示中'),
            value: settings.darkModeEnabled,
            onChanged: settings.setDarkModeEnabled,
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
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('バックアップを作成'),
            subtitle: const Text('メモ・ジャンル・録音データをまとめて保存先を選んで保存します'),
            onTap: () => _createBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('バックアップから復元'),
            subtitle: const Text('保存しておいたバックアップファイルからメモを復元します'),
            onTap: () => _restoreBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('削除済み'),
            subtitle: const Text('削除したメモは5日間ここに残り、復元できます'),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TrashScreen())),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('アプリロック'),
            subtitle: Text(
              appLock.isEnabled
                  ? '起動時・復帰時にパスワードを求めます'
                  : 'パスワードを設定して、起動時のセキュリティを強化します',
            ),
            value: appLock.isEnabled,
            onChanged: (value) =>
                value ? _enableAppLock(context) : _disableAppLock(context),
          ),
          if (appLock.isEnabled)
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('アプリロックのパスワードを変更'),
              onTap: () => _changeAppLockPassword(context),
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
              onTap: () => _restorePurchases(context),
            ),
          ],
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: '手もとメモ',
            applicationVersion: '1.0.0',
            aboutBoxChildren: [
              Text('声も文字も、すぐ記録。広告に邪魔されず、音声メモ・文字起こし・ジャンル分類・検索ができるメモアプリです。'),
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
