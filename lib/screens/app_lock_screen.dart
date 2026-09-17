import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_lock_provider.dart';
import '../widgets/app_lock_recovery_dialog.dart';

/// アプリロックが有効なときに、起動時・バックグラウンド復帰時に表示する
/// パスワード入力画面。正しいパスワードが入力されるまで、この画面が
/// アプリ本体の代わりに表示され続ける。
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _checking = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _errorText = 'パスワードを入力してください');
      return;
    }
    setState(() {
      _checking = true;
      _errorText = null;
    });
    final provider = context.read<AppLockProvider>();
    final ok = await provider.unlock(password);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _checking = false;
        _errorText = 'パスワードが正しくありません';
      });
    }
    // 成功時は Provider の isLocked が変わり、この画面自体が
    // ツリーから外れるので、ここで setState する必要はない。
  }

  Future<void> _recover() async {
    final provider = context.read<AppLockProvider>();
    final question = await provider.getSecretQuestion();
    if (!mounted) return;
    if (question == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('秘密の質問が設定されていません')));
      return;
    }

    final result = await showAppLockRecoveryDialog(
      context,
      secretQuestion: question,
    );
    if (result == null) return;
    final (secretAnswer, newMainPassword) = result;

    if (!mounted) return;
    final ok = await provider.recoverWithSecretAnswer(
      secretAnswer: secretAnswer,
      newMainPassword: newMainPassword,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('答えが正しくありません')));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('新しいメインパスワードを設定しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  '手もとメモ はロックされています',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: _obscure,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    errorText: _errorText,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checking ? null : _unlock,
                    child: const Text('ロック解除'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _checking ? null : _recover,
                  child: const Text('パスワードを忘れた場合'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
