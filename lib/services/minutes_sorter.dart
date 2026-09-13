/// 文字起こし結果を、議事録テンプレートの見出しへ簡易的に振り分けるロジック。
///
/// Vosk (オフライン音声認識) は句読点を付けないため、文の区切りは「。」などの
/// 記号や単純な空白から推測するしかなく、内容を理解した要約はできない。
/// ここでやっているのは、キーワードを含む文を「それっぽい」見出しの下に
/// 移動させるだけの簡易ロジック(完全にオフラインで完結する)。
/// 一致する見出しが本文に無い、あるいはどのキーワードにも一致しない文は、
/// 従来通り本文の末尾にそのまま追記する。
class MinutesSorter {
  const MinutesSorter._();

  static const _rules = <_SortRule>[
    _SortRule(
      headingSubstrings: ['決定'],
      triggerKeywords: ['決定', '決まり', 'ことにします', 'ことになりました', '確定'],
    ),
    _SortRule(
      headingSubstrings: ['ToDo', 'アクション', '宿題'],
      triggerKeywords: ['お願いします', 'までに', '担当', '対応します', 'やっておきます', 'やります'],
    ),
    _SortRule(
      headingSubstrings: ['次回'],
      triggerKeywords: ['次回', '来週', '再来週', '次の会議', '次のミーティング'],
    ),
    _SortRule(
      headingSubstrings: ['議題'],
      triggerKeywords: ['議題', 'について話し', 'について検討', 'についてです'],
    ),
    _SortRule(
      headingSubstrings: ['共有'],
      triggerKeywords: ['共有します', '共有です', '共有事項', '共有したい'],
    ),
    _SortRule(
      headingSubstrings: ['フィードバック'],
      triggerKeywords: ['フィードバック', '良かった点', '改善点', '良かったです'],
    ),
    _SortRule(
      headingSubstrings: ['アイデア'],
      triggerKeywords: ['アイデア', '案として', 'はどうでしょう', '提案です'],
    ),
  ];

  /// [templateContent](テンプレートや既存の本文)に、文字起こし結果
  /// [transcript] を見出しごとに振り分けて挿入した結果を返す。
  static String applyToTemplate(String templateContent, String transcript) {
    final sentences = _splitSentences(transcript);
    if (sentences.isEmpty) return templateContent;

    var result = templateContent;
    final unmatched = <String>[];

    for (final sentence in sentences) {
      final heading = _findMatchingHeading(result, sentence);
      if (heading == null) {
        unmatched.add(sentence);
        continue;
      }
      result = _insertUnderHeading(result, heading, sentence);
    }

    if (unmatched.isNotEmpty) {
      final joined = unmatched.join('\n');
      result = result.isEmpty ? joined : '$result\n$joined';
    }

    return result;
  }

  /// 句点(。.!? など)で文を分割する。句読点が無い場合は全体を1文として扱う。
  static List<String> _splitSentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];
    final parts = normalized
        .split(RegExp(r'(?<=[。.!?！?])\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? [normalized] : parts;
  }

  /// [sentence] のキーワードに一致するルールの中から、実際に [content] に
  /// 見出しとして存在するものを探す(先勝ち)。見つからなければ null。
  static String? _findMatchingHeading(String content, String sentence) {
    final headingLines = content
        .split('\n')
        .where((line) => line.contains('【') && line.contains('】'));

    for (final rule in _rules) {
      if (!rule.triggerKeywords.any(sentence.contains)) continue;
      for (final line in headingLines) {
        if (rule.headingSubstrings.any(line.contains)) {
          return line;
        }
      }
    }
    return null;
  }

  /// [headingLine] という見出し行の直後(次の見出しか本文末尾の手前)に
  /// [sentence] を挿入する。
  static String _insertUnderHeading(
    String content,
    String headingLine,
    String sentence,
  ) {
    final lines = content.split('\n');
    final headingIndex = lines.indexOf(headingLine);
    if (headingIndex == -1) return '$content\n$sentence';

    var insertAt = headingIndex + 1;
    while (insertAt < lines.length &&
        lines[insertAt].trim().isNotEmpty &&
        !lines[insertAt].contains('【')) {
      insertAt++;
    }
    lines.insert(insertAt, sentence);
    return lines.join('\n');
  }
}

class _SortRule {
  const _SortRule({required this.headingSubstrings, required this.triggerKeywords});

  final List<String> headingSubstrings;
  final List<String> triggerKeywords;
}
