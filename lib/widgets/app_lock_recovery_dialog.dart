import 'package:flutter/material.dart';

/// メインパスワードを忘れた場合の復旧ダイアログ。
///
/// [secretQuestion] を表示した上で、その答えと、新しいメインパスワード
/// (確認込み)を入力してもらう。ここでは入力内容の整合性(一致している
/// か)だけを確認し、答えが正しいかどうかは呼び出し側で検証すること。
///
/// 戻り値は `(secretAnswer, newMainPassword)`。キャンセル時は null。
Future<(String, String)?> showAppLockRecoveryDialog(
  BuildContext context, {
  required String secretQuestion,
}) async {
  final answerController = TextEditingController();
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
              title: const Text('秘密の質問で復旧'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      secretQuestion,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: answerController,
                      autofocus: true,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: '答え',
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
                    final answer = answerController.text;
                    final newMain = newMainController.text;
                    final newMainConfirm = newMainConfirmController.text;
                    if (answer.isEmpty || newMain.isEmpty) {
                      setState(() => errorText = 'すべての項目を入力してください');
                      return;
                    }
                    if (newMain != newMainConfirm) {
                      setState(() => errorText = '新しいメインパスワードが一致しません');
                      return;
                    }
                    Navigator.of(dialogContext).pop((answer, newMain));
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
    answerController.dispose();
    newMainController.dispose();
    newMainConfirmController.dispose();
  }
}
