import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/genre.dart';
import '../models/memo.dart';
import '../models/memo_image.dart';

/// メモの共有・エクスポート(端末外への書き出し)を担うサービス。
class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  /// テキスト・音声・添付画像/動画のうち、選択された組み合わせをまとめて
  /// 共有する(OS標準の共有シートを開く)。呼び出し側(メモ編集画面)で
  /// どれを含めるか選ばせてから呼ぶ。
  ///
  /// テキストとファイル(音声・画像・動画)を両方選んだ場合、共有操作を
  /// 2回に分けて行う: LINEなど一部のアプリは、画像と一緒に渡された
  /// テキスト(Android の EXTRA_TEXT)を送信時に無視してしまい、
  /// 「写真とメモを両方選んだのに写真しか届かない」という結果になる
  /// (share_plus 側は EXTRA_TEXT を正しく渡しており、受け取ったアプリが
  /// 使わないだけ)。1回にまとめず、まずテキストだけ共有し、利用者が
  /// 共有シートを閉じた後に続けてファイルだけ共有すれば、それぞれ
  /// 独立したメッセージとして確実に届く。
  Future<void> shareMemo({
    required Memo memo,
    Genre? genre,
    required bool includeText,
    required bool includeAudio,
    required List<MemoImage> images,
  }) async {
    final files = <XFile>[
      if (includeAudio && memo.hasAudio) XFile(memo.audioPath!),
      for (final image in images) XFile(image.path),
    ];
    if (!includeText && files.isEmpty) return;

    final subject = memo.title.isEmpty ? 'メモ' : memo.title;

    if (includeText && files.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(text: _buildMemoText(memo, genre), subject: subject),
      );
      await SharePlus.instance.share(
        ShareParams(files: files, subject: subject),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: includeText ? _buildMemoText(memo, genre) : null,
        files: files.isEmpty ? null : files,
        subject: subject,
      ),
    );
  }

  String _buildMemoText(Memo memo, Genre? genre) {
    final buffer = StringBuffer();
    if (memo.title.isNotEmpty) {
      buffer.writeln(memo.title);
      buffer.writeln();
    }
    buffer.writeln(memo.content);
    if (genre != null) {
      buffer.writeln();
      buffer.writeln('ジャンル: ${genre.name}');
    }
    return buffer.toString();
  }

  /// 全メモをジャンルごとにまとめた1つのテキストファイルとして書き出し、
  /// 共有シート経由で保存・送信できるようにする。
  Future<void> exportAllMemos(List<Memo> memos, List<Genre> genres) async {
    final content = _buildExportText(memos, genres);

    final tmpDir = await getTemporaryDirectory();
    final fileName =
        'memo_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';
    final file = File(p.join(tmpDir.path, fileName));
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'メモのエクスポート'),
    );
  }

  String _buildExportText(List<Memo> memos, List<Genre> genres) {
    final buffer = StringBuffer();
    buffer.writeln('手もとメモ エクスポート (${_dateFormat.format(DateTime.now())})');
    buffer.writeln('=' * 40);

    final genreById = {for (final g in genres) g.id: g};
    final grouped = <String, List<Memo>>{};
    for (final memo in memos) {
      final key = memo.genreId ?? '__unassigned__';
      grouped.putIfAbsent(key, () => []).add(memo);
    }

    final orderedGroupKeys = [
      ...genres.map((g) => g.id).where(grouped.containsKey),
      if (grouped.containsKey('__unassigned__')) '__unassigned__',
    ];

    for (final key in orderedGroupKeys) {
      final groupGenre = genreById[key];
      buffer.writeln();
      buffer.writeln('## ${groupGenre?.name ?? '未分類'}');
      buffer.writeln();

      for (final memo in grouped[key]!) {
        if (memo.title.isNotEmpty) {
          buffer.writeln('■ ${memo.title}');
        } else {
          buffer.writeln('■ (無題のメモ)');
        }
        buffer.writeln('更新: ${_dateFormat.format(memo.updatedAt)}');
        if (memo.hasAudio) {
          buffer.writeln('(音声メモあり)');
        }
        buffer.writeln(memo.content);
        buffer.writeln('-' * 24);
      }
    }

    return buffer.toString();
  }
}
