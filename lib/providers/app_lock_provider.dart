import 'package:flutter/foundation.dart';

import '../services/app_lock_service.dart';

/// アプリロック(起動時・バックグラウンド復帰時のパスワード要求)の
/// 状態を管理する。
class AppLockProvider extends ChangeNotifier {
  AppLockProvider({AppLockService? service})
    : _service = service ?? AppLockService();

  final AppLockService _service;

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  bool _isUnlocked = true;

  /// ロック画面を表示すべきかどうか。
  bool get isLocked => _isEnabled && !_isUnlocked;

  Future<void> init() async {
    _isEnabled = await _service.isEnabled();
    _isUnlocked = !_isEnabled;
    notifyListeners();
  }

  /// アプリロックを有効にする(初回設定)。この場では既にアプリの中に
  /// いるユーザーなので、設定直後は解錠済み扱いにする。
  Future<void> enable({
    required String mainPassword,
    required String secretPassword,
  }) async {
    await _service.setUp(
      mainPassword: mainPassword,
      secretPassword: secretPassword,
    );
    _isEnabled = true;
    _isUnlocked = true;
    notifyListeners();
  }

  Future<void> disable() async {
    await _service.disable();
    _isEnabled = false;
    _isUnlocked = true;
    notifyListeners();
  }

  /// 現在のメインパスワードで照合が取れた場合のみパスワードを変更する。
  Future<bool> changePassword({
    required String currentMainPassword,
    required String newMainPassword,
    required String newSecretPassword,
  }) async {
    final ok = await _service.verifyMainPassword(currentMainPassword);
    if (!ok) return false;
    await _service.setUp(
      mainPassword: newMainPassword,
      secretPassword: newSecretPassword,
    );
    return true;
  }

  /// 状態を変更せずにメインパスワードを照合するだけ。ロック解除を伴わない
  /// 確認(ロックを無効化する前・パスワードを変更する前など)に使う。
  Future<bool> verifyMainPassword(String password) {
    return _service.verifyMainPassword(password);
  }

  Future<bool> unlock(String password) async {
    final ok = await _service.verifyMainPassword(password);
    if (ok) {
      _isUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  /// 秘密のパスワードで認証できれば、メインパスワードを差し替えて
  /// 解錠する。
  Future<bool> recoverWithSecretPassword({
    required String secretPassword,
    required String newMainPassword,
  }) async {
    final ok = await _service.verifySecretPassword(secretPassword);
    if (!ok) return false;
    await _service.resetMainPassword(newMainPassword);
    _isUnlocked = true;
    notifyListeners();
    return true;
  }

  /// バックグラウンドに退避した際などに呼び、次回は再度パスワードを
  /// 要求するようにする。
  void lock() {
    if (!_isEnabled || !_isUnlocked) return;
    _isUnlocked = false;
    notifyListeners();
  }
}
