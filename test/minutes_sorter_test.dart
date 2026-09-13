import 'package:flutter_test/flutter_test.dart';
import 'package:memo_app/services/minutes_sorter.dart';

void main() {
  group('MinutesSorter', () {
    test('sorts sentences under matching headings', () {
      const template = '''【議題】

【決定事項】

【ToDo(担当・期限)】

【次回予定】
''';
      const transcript =
          '来週の予算について話します。予算を10%増やすことに決定しました。'
          '資料の作成は田中さんにお願いします。次回は来週の水曜日に行います。';

      final result = MinutesSorter.applyToTemplate(template, transcript);

      final decidedIndex = result.indexOf('【決定事項】');
      final todoIndex = result.indexOf('【ToDo');
      final nextIndex = result.indexOf('【次回予定】');

      expect(
        result.indexOf('予算を10%増やすことに決定しました。'),
        greaterThan(decidedIndex),
      );
      expect(
        result.indexOf('資料の作成は田中さんにお願いします。'),
        greaterThan(todoIndex),
      );
      expect(
        result.indexOf('次回は来週の水曜日に行います。'),
        greaterThan(nextIndex),
      );
    });

    test('falls back to plain append when nothing matches', () {
      const template = 'メモ';
      const transcript = '今日は天気がいいです';

      final result = MinutesSorter.applyToTemplate(template, transcript);

      expect(result, 'メモ\n今日は天気がいいです');
    });

    test('appends unmatched sentences even when other sentences sort', () {
      const template = '【決定事項】\n';
      const transcript = '予算を増やすことに決定しました。今日はいい天気です。';

      final result = MinutesSorter.applyToTemplate(template, transcript);

      expect(result, contains('予算を増やすことに決定しました。'));
      expect(result, contains('今日はいい天気です。'));
    });

    test('returns the template unchanged for an empty transcript', () {
      const template = '【決定事項】\n';
      expect(MinutesSorter.applyToTemplate(template, ''), template);
    });
  });
}
