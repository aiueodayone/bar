import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリロック(起動時・復帰時にパスワードを求める機能)の設定と検証を
/// 扱うサービス。
///
/// パスワードそのものは保存しない。PBKDF2-HMAC-SHA256 でハッシュ化した
/// 値と salt だけを SharedPreferences に保存し、照合時は入力された
/// パスワードを同じ salt で再度ハッシュ化して比較する。
///
/// メインパスワードとは別に「秘密のパスワード」も同じ方式で保存する。
/// これはメインパスワードを万が一忘れてしまったときの復旧専用の
/// パスワードで、これで認証できればメインパスワードを設定し直せる。
class AppLockService {
  static const _keyEnabled = 'app_lock_enabled';
  static const _keyMainHash = 'app_lock_main_hash';
  static const _keyMainSalt = 'app_lock_main_salt';
  static const _keySecretHash = 'app_lock_secret_hash';
  static const _keySecretSalt = 'app_lock_secret_salt';

  static const int _iterations = 120000;
  static const int _saltLength = 16;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// メインパスワードと秘密のパスワードを設定し、アプリロックを有効にする。
  Future<void> setUp({
    required String mainPassword,
    required String secretPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _store(prefs, _keyMainHash, _keyMainSalt, mainPassword);
    await _store(prefs, _keySecretHash, _keySecretSalt, secretPassword);
    await prefs.setBool(_keyEnabled, true);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    await prefs.remove(_keyMainHash);
    await prefs.remove(_keyMainSalt);
    await prefs.remove(_keySecretHash);
    await prefs.remove(_keySecretSalt);
  }

  Future<bool> verifyMainPassword(String password) async {
    return _verify(password, _keyMainHash, _keyMainSalt);
  }

  Future<bool> verifySecretPassword(String password) async {
    return _verify(password, _keySecretHash, _keySecretSalt);
  }

  /// 秘密のパスワードでの復旧が成功したあとに呼ぶ。メインパスワードだけを
  /// 差し替える(秘密のパスワードはそのまま)。
  Future<void> resetMainPassword(String newMainPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await _store(prefs, _keyMainHash, _keyMainSalt, newMainPassword);
  }

  Future<void> _store(
    SharedPreferences prefs,
    String hashKey,
    String saltKey,
    String password,
  ) async {
    final salt = _randomSalt();
    await prefs.setString(hashKey, await _hash(password, salt));
    await prefs.setString(saltKey, base64Encode(salt));
  }

  Future<bool> _verify(String password, String hashKey, String saltKey) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(hashKey);
    final storedSalt = prefs.getString(saltKey);
    if (storedHash == null || storedSalt == null) return false;
    final salt = base64Decode(storedSalt);
    final hash = await _hash(password, salt);
    return _constantTimeEquals(hash, storedHash);
  }

  Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<String> _hash(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2.hmacSha256(iterations: _iterations, bits: 256);
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
