import 'package:flutter/material.dart';

/// バックアップ作成時のパスワード設定ダイアログを表示する。
///
/// 戻り値の意味:
/// - `null`: ユーザーがキャンセルした(バックアップ作成自体を中止する)
/// - `''`(空文字列): パスワードなしで作成する
/// - それ以外: このパスワードで暗号化して作成する
Future<String?> showBackupPasswordSetupDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('バックアップを暗号化しますか?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'パスワードを設定すると、このバックアップは中身をそのまま'
                    '読み取れないように暗号化されます。空欄のままなら暗号化せずに'
                    '作成します。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'このパスワードを忘れると、このバックアップからは二度と'
                    '復元できません。',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    autofocus: true,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'パスワード(任意)',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: const InputDecoration(labelText: 'パスワード(確認)'),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final password = passwordController.text;
                    final confirm = confirmController.text;
                    if (password.isEmpty && confirm.isEmpty) {
                      Navigator.of(dialogContext).pop('');
                      return;
                    }
                    if (password != confirm) {
                      setState(() => errorText = 'パスワードが一致しません');
                      return;
                    }
                    Navigator.of(dialogContext).pop(password);
                  },
                  child: const Text('バックアップを作成'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    passwordController.dispose();
    confirmController.dispose();
  }
}

/// バックアップ復元時、暗号化されたバックアップだったときにパスワードを
/// 尋ねるダイアログを表示する。キャンセル時は null を返す。
Future<String?> showBackupPasswordPromptDialog(BuildContext context) async {
  final controller = TextEditingController();

  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('パスワードを入力'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'このバックアップはパスワードで保護されています。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (controller.text.isEmpty) {
                        setState(() => errorText = 'パスワードを入力してください');
                        return;
                      }
                      Navigator.of(dialogContext).pop(controller.text);
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.isEmpty) {
                      setState(() => errorText = 'パスワードを入力してください');
                      return;
                    }
                    Navigator.of(dialogContext).pop(controller.text);
                  },
                  child: const Text('復元する'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
