import 'package:flutter/material.dart';

/// 1つのパスワード入力欄だけのシンプルな確認ダイアログ。
///
/// キャンセル時は null、入力されたパスワードで「決定」が押されたときは
/// その文字列を返す(空文字のままでは決定できない)。
Future<String?> showSimplePasswordPromptDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String fieldLabel = 'パスワード',
}) async {
  final controller = TextEditingController();

  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void submit() {
              if (controller.text.isEmpty) {
                setState(() => errorText = 'パスワードを入力してください');
                return;
              }
              Navigator.of(dialogContext).pop(controller.text);
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: fieldLabel,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                    onSubmitted: (_) => submit(),
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
                FilledButton(onPressed: submit, child: Text(confirmLabel)),
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
