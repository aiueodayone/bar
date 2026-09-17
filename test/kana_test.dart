import 'package:flutter_test/flutter_test.dart';
import 'package:memo_app/utils/kana.dart';

void main() {
  group('normalizeForSearch', () {
    test('converts katakana to hiragana', () {
      expect(normalizeForSearch('メモ'), normalizeForSearch('めも'));
    });

    test('matches mixed hiragana/katakana substrings', () {
      final normalizedQuery = normalizeForSearch('めも');
      expect(normalizeForSearch('今日のメモ帳').contains(normalizedQuery), isTrue);
    });

    test('lowercases ascii letters', () {
      expect(normalizeForSearch('Memo'), normalizeForSearch('memo'));
    });

    test('leaves kanji and other characters unchanged', () {
      expect(normalizeForSearch('議事録'), '議事録');
    });
  });
}
