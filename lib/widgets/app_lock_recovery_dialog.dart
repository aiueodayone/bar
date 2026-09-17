import 'package:flutter/material.dart';

/// メインパスワードを忘れた場合の復旧ダイアログ。
///
/// 秘密のパスワードと、新しいメインパスワード(確認込み)を入力してもらう。
/// ここでは入力内容の整合性(一致しているか)だけを確認し、秘密の
/// パスワードが正しいかどうかは呼び出し側で検証すること。
///
/// 戻り値は `(secretPassword, newMainPassword)`。キャンセル時は null。
Future<(String, String)?> showAppLockRecoveryDialog(
  BuildContext context,
) async {
  final secretController = TextEditingController();
  final newMainController = TextEditingController();
  final newMainConfirmController = TextEditingController();

  try {
    return await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('秘密のパスワードで復旧'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '設定しておいた秘密のパスワードと、新しいメインパスワードを'
                      '入力してください。',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: secretController,
                      autofocus: true,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: '秘密のパスワード',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newMainController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: '新しいメインパスワード',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newMainConfirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: '新しいメインパスワード(確認)',
                      ),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final secret = secretController.text;
                    final newMain = newMainController.text;
                    final newMainConfirm = newMainConfirmController.text;
                    if (secret.isEmpty || newMain.isEmpty) {
                      setState(() => errorText = 'すべての項目を入力してください');
                      return;
                    }
                    if (newMain != newMainConfirm) {
                      setState(() => errorText = '新しいメインパスワードが一致しません');
                      return;
                    }
                    Navigator.of(dialogContext).pop((secret, newMain));
                  },
                  child: const Text('復旧する'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    secretController.dispose();
    newMainController.dispose();
    newMainConfirmController.dispose();
  }
}
