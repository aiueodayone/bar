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
/// メインパスワードとは別に「秘密の質問」も保存する。これはメイン
/// パスワードを万が一忘れてしまったときの復旧専用で、単独の第二
/// パスワードよりも思い出しやすいよう、質問と答えのペアにしてある。
/// 質問文はヒントとして画面に出す必要があるため平文で保存し、答えだけ
/// メインパスワードと同じ方式でハッシュ化する。
class AppLockService {
  static const _keyEnabled = 'app_lock_enabled';
  static const _keyMainHash = 'app_lock_main_hash';
  static const _keyMainSalt = 'app_lock_main_salt';
  static const _keySecretQuestion = 'app_lock_secret_question';
  static const _keySecretAnswerHash = 'app_lock_secret_answer_hash';
  static const _keySecretAnswerSalt = 'app_lock_secret_answer_salt';

  static const int _iterations = 120000;
  static const int _saltLength = 16;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  /// メインパスワードと、復旧用の秘密の質問・答えを設定し、アプリロックを
  /// 有効にする。
  Future<void> setUp({
    required String mainPassword,
    required String secretQuestion,
    required String secretAnswer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _store(prefs, _keyMainHash, _keyMainSalt, mainPassword);
    await _store(
      prefs,
      _keySecretAnswerHash,
      _keySecretAnswerSalt,
      _normalizeAnswer(secretAnswer),
    );
    await prefs.setString(_keySecretQuestion, secretQuestion);
    await prefs.setBool(_keyEnabled, true);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    await prefs.remove(_keyMainHash);
    await prefs.remove(_keyMainSalt);
    await prefs.remove(_keySecretQuestion);
    await prefs.remove(_keySecretAnswerHash);
    await prefs.remove(_keySecretAnswerSalt);
  }

  /// 復旧画面に表示する秘密の質問の文面。未設定なら null。
  Future<String?> getSecretQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySecretQuestion);
  }

  Future<bool> verifyMainPassword(String password) async {
    return _verify(password, _keyMainHash, _keyMainSalt);
  }

  Future<bool> verifySecretAnswer(String answer) async {
    return _verify(
      _normalizeAnswer(answer),
      _keySecretAnswerHash,
      _keySecretAnswerSalt,
    );
  }

  /// 秘密の質問での復旧が成功したあとに呼ぶ。メインパスワードだけを
  /// 差し替える(質問・答えはそのまま)。
  Future<void> resetMainPassword(String newMainPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await _store(prefs, _keyMainHash, _keyMainSalt, newMainPassword);
  }

  /// 答えの表記ゆれ(前後の空白・大文字小文字)を吸収する。パスワードと
  /// 違って「質問に対する答え」は毎回一字一句同じに入力し直すのが
  /// 難しいことがあるため、照合だけは緩くする。
  String _normalizeAnswer(String answer) => answer.trim().toLowerCase();

  Future<void> _store(
    SharedPreferences prefs,
    String hashKey,
    String saltKey,
    String value,
  ) async {
    final salt = _randomSalt();
    await prefs.setString(hashKey, await _hash(value, salt));
    await prefs.setString(saltKey, base64Encode(salt));
  }

  Future<bool> _verify(String value, String hashKey, String saltKey) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(hashKey);
    final storedSalt = prefs.getString(saltKey);
    if (storedHash == null || storedSalt == null) return false;
    final salt = base64Decode(storedSalt);
    final hash = await _hash(value, salt);
    return _constantTimeEquals(hash, storedHash);
  }

  Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<String> _hash(String value, List<int> salt) async {
    final pbkdf2 = Pbkdf2.hmacSha256(iterations: _iterations, bits: 256);
    final key = await pbkdf2.deriveKeyFromPassword(
      password: value,
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
