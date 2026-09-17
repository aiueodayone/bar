/// 検索用に文字列を正規化する。カタカナをひらがなに寄せ、英字は小文字化する
/// ことで、「めも」で「メモ」を、"Memo" で "memo" を検索できるようにする。
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    // カタカナ(U+30A1〜U+30F6)は、対応するひらがな(U+3041〜U+3096)より
    // 0x60 だけ大きいコードポイントに割り当てられているため、その分だけ
    // 引けばひらがなに変換できる(「ヴ」U+30F4 なども含め、この範囲内で
    // 概ね機械的に対応する)。
    if (rune >= 0x30A1 && rune <= 0x30F6) {
      buffer.writeCharCode(rune - 0x60);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().toLowerCase();
}
