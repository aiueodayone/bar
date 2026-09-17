import 'package:flutter/material.dart';

/// アプリロックのメインパスワード・秘密のパスワードを設定するダイアログ。
///
/// 戻り値は `(mainPassword, secretPassword)`。キャンセル時は null。
/// 新規設定にも、パスワード変更にも使う。
Future<(String, String)?> showAppLockSetupDialog(
  BuildContext context, {
  String title = 'アプリロックを設定',
}) async {
  final mainController = TextEditingController();
  final mainConfirmController = TextEditingController();
  final secretController = TextEditingController();
  final secretConfirmController = TextEditingController();

  try {
    return await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '起動時・バックグラウンドからの復帰時に、このパスワードを'
                      '求めるようになります。',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: mainController,
                      autofocus: true,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'メインパスワード',
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
                      controller: mainConfirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'メインパスワード(確認)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'メインパスワードを万が一忘れてしまった場合に備えて、'
                      '復旧用の「秘密のパスワード」も設定してください。',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      'これも忘れてしまうと、アプリロックを解除する手段が'
                      'なくなります。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretController,
                      obscureText: obscure,
                      decoration: const InputDecoration(labelText: '秘密のパスワード'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: secretConfirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: '秘密のパスワード(確認)',
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
                    final main = mainController.text;
                    final mainConfirm = mainConfirmController.text;
                    final secret = secretController.text;
                    final secretConfirm = secretConfirmController.text;

                    if (main.isEmpty || secret.isEmpty) {
                      setState(() => errorText = 'メインパスワードと秘密のパスワードを入力してください');
                      return;
                    }
                    if (main != mainConfirm) {
                      setState(() => errorText = 'メインパスワードが一致しません');
                      return;
                    }
                    if (secret != secretConfirm) {
                      setState(() => errorText = '秘密のパスワードが一致しません');
                      return;
                    }
                    if (main == secret) {
                      setState(
                        () => errorText = 'メインパスワードと秘密のパスワードは別のものにしてください',
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop((main, secret));
                  },
                  child: const Text('設定する'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    mainController.dispose();
    mainConfirmController.dispose();
    secretController.dispose();
    secretConfirmController.dispose();
  }
}
