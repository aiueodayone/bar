import 'package:flutter/material.dart';

/// 秘密の質問としてあらかじめ用意しておく選択肢。
const List<String> kSecretQuestionPresets = [
  '子供の頃のあだ名は?',
  '初めて飼ったペットの名前は?',
  '出身小学校の名前は?',
  '好きな食べ物は?',
  '母親の旧姓は?',
];

/// 「自分で質問を入力する」を選んだことを示す内部的な値。
const String _customQuestionValue = '__custom__';

/// アプリロックのメインパスワード・秘密の質問と答えを設定するダイアログ。
///
/// 戻り値は `(mainPassword, secretQuestion, secretAnswer)`。
/// キャンセル時は null。新規設定にも、パスワード変更にも使う。
Future<(String, String, String)?> showAppLockSetupDialog(
  BuildContext context, {
  String title = 'アプリロックを設定',
}) async {
  final mainController = TextEditingController();
  final mainConfirmController = TextEditingController();
  final customQuestionController = TextEditingController();
  final answerController = TextEditingController();
  final answerConfirmController = TextEditingController();

  try {
    return await showDialog<(String, String, String)>(
      context: context,
      builder: (dialogContext) {
        var obscure = true;
        String? selectedQuestion;
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
                      '復旧用の「秘密の質問」も設定してください。',
                      style: TextStyle(fontSize: 13),
                    ),
                    const Text(
                      'これも答えられなくなると、アプリロックを解除する手段が'
                      'なくなります。',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedQuestion,
                      decoration: const InputDecoration(labelText: '秘密の質問'),
                      items: [
                        for (final q in kSecretQuestionPresets)
                          DropdownMenuItem(value: q, child: Text(q)),
                        const DropdownMenuItem(
                          value: _customQuestionValue,
                          child: Text('自分で質問を入力する'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedQuestion = value),
                    ),
                    if (selectedQuestion == _customQuestionValue) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customQuestionController,
                        decoration: const InputDecoration(labelText: '質問の内容'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerController,
                      obscureText: obscure,
                      decoration: const InputDecoration(labelText: '答え'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: answerConfirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(labelText: '答え(確認)'),
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
                    final answer = answerController.text;
                    final answerConfirm = answerConfirmController.text;
                    final question = selectedQuestion == _customQuestionValue
                        ? customQuestionController.text.trim()
                        : selectedQuestion;

                    if (main.isEmpty) {
                      setState(() => errorText = 'メインパスワードを入力してください');
                      return;
                    }
                    if (main != mainConfirm) {
                      setState(() => errorText = 'メインパスワードが一致しません');
                      return;
                    }
                    if (question == null || question.isEmpty) {
                      setState(() => errorText = '秘密の質問を選択・入力してください');
                      return;
                    }
                    if (answer.isEmpty) {
                      setState(() => errorText = '答えを入力してください');
                      return;
                    }
                    if (answer != answerConfirm) {
                      setState(() => errorText = '答えが一致しません');
                      return;
                    }
                    if (main == answer) {
                      setState(() => errorText = 'メインパスワードと答えは別のものにしてください');
                      return;
                    }
                    Navigator.of(dialogContext).pop((main, question, answer));
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
    customQuestionController.dispose();
    answerController.dispose();
    answerConfirmController.dispose();
  }
}
