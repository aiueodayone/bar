import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/genre.dart';
import '../models/memo.dart';

/// メモの共有・エクスポート(端末外への書き出し)を担うサービス。
class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  /// 1件のメモをテキストとして共有する(OS標準の共有シートを開く)。
  Future<void> shareMemoText(Memo memo, Genre? genre) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _buildMemoText(memo, genre),
        subject: memo.title.isEmpty ? 'メモ' : memo.title,
      ),
    );
  }

  /// 音声メモの録音ファイルを共有する。
  Future<void> shareMemoAudio(Memo memo) async {
    if (!memo.hasAudio) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(memo.audioPath!)],
        subject: memo.title.isEmpty ? '音声メモ' : memo.title,
      ),
    );
  }

  /// 音声メモの録音ファイルと、そのテキスト(文字起こし結果を含む)をまとめて
  /// 共有する。メールなど、添付ファイルと本文を同時に送れる共有先向け。
  Future<void> shareMemoAudioWithText(Memo memo, Genre? genre) async {
    if (!memo.hasAudio) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(memo.audioPath!)],
        text: _buildMemoText(memo, genre),
        subject: memo.title.isEmpty ? '音声メモ' : memo.title,
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
  Future<void> exportAllMemos(
    List<Memo> memos,
    List<Genre> genres,
  ) async {
    final content = _buildExportText(memos, genres);

    final tmpDir = await getTemporaryDirectory();
    final fileName =
        'memo_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';
    final file = File(p.join(tmpDir.path, fileName));
    await file.writeAsString(content);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'メモのエクスポート',
      ),
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
