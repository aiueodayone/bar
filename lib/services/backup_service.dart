import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/genre_repository.dart';
import '../data/memo_repository.dart';
import '../models/genre.dart';
import '../models/memo.dart';

/// バックアップファイル(backup.json)の形式バージョン。
///
/// 将来 DB のスキーマが変わって backup.json の中身の構造を変える必要が
/// 出たときは、このバージョンを上げ、[BackupService.restoreFromBackup] に
/// 旧バージョンの読み取り分岐を追加すること。バックアップの中身は SQLite の
/// 生ダンプではなく素の JSON なので、アプリのバージョンアップ後もこの
/// バージョン番号さえ見れば読めるかどうか判断できる。
const int kBackupFormatVersion = 1;

/// バックアップファイルが新しすぎて読み取れないときの例外。
class UnsupportedBackupVersionException implements Exception {
  const UnsupportedBackupVersionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// バックアップとして認識できないファイルを渡されたときの例外。
class InvalidBackupFileException implements Exception {
  const InvalidBackupFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// メモ・ジャンル・録音データをまとめてバックアップ/復元するサービス。
///
/// バックアップは ZIP ファイル1つにまとめる: メモ・ジャンルのデータは
/// backup.json、録音ファイルは audio/ フォルダ以下にそのまま含める。
/// 復元は既存データを削除せず、同じ ID のものは上書き、無いものは追加する
/// (マージ)。誤って新しいメモを消してしまうことがないようにするため。
class BackupService {
  BackupService({
    MemoRepository? memoRepository,
    GenreRepository? genreRepository,
  }) : _memoRepository = memoRepository ?? MemoRepository(),
       _genreRepository = genreRepository ?? GenreRepository();

  final MemoRepository _memoRepository;
  final GenreRepository _genreRepository;

  /// 全メモ・ジャンル・録音ファイルをまとめた ZIP バックアップを作成し、
  /// 共有シート経由で保存できるようにする。
  Future<void> createAndShareBackup() async {
    final genres = await _genreRepository.fetchGenres();
    final memos = await _memoRepository.fetchMemos();

    final archive = Archive();
    final audioFileByMemoId = <String, String>{};

    for (final memo in memos) {
      if (!memo.hasAudio) continue;
      final file = File(memo.audioPath!);
      if (!await file.exists()) continue;
      final zipPath = 'audio/${p.basename(memo.audioPath!)}';
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
      audioFileByMemoId[memo.id] = zipPath;
    }

    final data = <String, Object?>{
      'backupVersion': kBackupFormatVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'genres': [
        for (final genre in genres)
          {'id': genre.id, 'name': genre.name, 'color': genre.color.toARGB32()},
      ],
      'memos': [
        for (final memo in memos)
          {
            'id': memo.id,
            'title': memo.title,
            'content': memo.content,
            'genreId': memo.genreId,
            'audioFile': audioFileByMemoId[memo.id],
            'audioDurationMs': memo.audioDurationMs,
            'createdAt': memo.createdAt.millisecondsSinceEpoch,
            'updatedAt': memo.updatedAt.millisecondsSinceEpoch,
          },
      ],
    };

    final jsonBytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('バックアップの作成に失敗しました');
    }

    final tmpDir = await getTemporaryDirectory();
    final fileName =
        'temotomemo_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File(p.join(tmpDir.path, fileName));
    await zipFile.writeAsBytes(zipBytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(zipFile.path)], subject: '手もとメモ バックアップ'),
    );
  }

  /// バックアップ ZIP ファイル(のバイト列)からメモ・ジャンル・録音データを
  /// 復元する。戻り値は (復元したメモ件数, 復元したジャンル件数)。
  ///
  /// ファイルパスではなくバイト列を受け取る: Android では file_picker が
  /// 選択結果を `content://` の URI で返すことがあり、その場合
  /// `PlatformFile.path` は null になるため、常に `readAsBytes()` 経由で
  /// 読み込む方が確実。
  Future<(int, int)> restoreFromBackup(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const InvalidBackupFileException('このファイルはバックアップとして読み取れませんでした');
    }

    final jsonEntries = archive.files.where((f) => f.name == 'backup.json');
    if (jsonEntries.isEmpty) {
      throw const InvalidBackupFileException('このファイルは手もとメモのバックアップではないようです');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(
        utf8.decode(jsonEntries.first.content as List<int>),
      ) as Map<String, dynamic>;
    } catch (_) {
      throw const InvalidBackupFileException('バックアップファイルの内容を読み取れませんでした');
    }

    final backupVersion = data['backupVersion'] as int? ?? 1;
    if (backupVersion > kBackupFormatVersion) {
      throw UnsupportedBackupVersionException(
        'このバックアップ(形式バージョン $backupVersion)は、お使いのアプリより'
        '新しい形式です。アプリを最新版に更新してからお試しください。',
      );
    }

    final genresJson = (data['genres'] as List<dynamic>?) ?? const [];
    for (var i = 0; i < genresJson.length; i++) {
      final g = genresJson[i] as Map<String, dynamic>;
      final genre = Genre(
        id: g['id'] as String,
        name: g['name'] as String,
        color: Color(g['color'] as int),
      );
      await _genreRepository.upsertGenre(genre, sortOrder: i);
    }

    final audioDir = await _voiceMemosDirectory();
    final memosJson = (data['memos'] as List<dynamic>?) ?? const [];
    for (final entry in memosJson) {
      final memoMap = entry as Map<String, dynamic>;
      String? restoredAudioPath;
      final audioFileInZip = memoMap['audioFile'] as String?;
      if (audioFileInZip != null) {
        final match = archive.files.where((f) => f.name == audioFileInZip);
        if (match.isNotEmpty) {
          final outPath = p.join(audioDir.path, p.basename(audioFileInZip));
          await File(outPath).writeAsBytes(match.first.content as List<int>);
          restoredAudioPath = outPath;
        }
      }

      final memo = Memo(
        id: memoMap['id'] as String,
        title: memoMap['title'] as String,
        content: memoMap['content'] as String,
        genreId: memoMap['genreId'] as String?,
        audioPath: restoredAudioPath,
        audioDurationMs: memoMap['audioDurationMs'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          memoMap['createdAt'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          memoMap['updatedAt'] as int,
        ),
      );
      await _memoRepository.upsertMemo(memo);
    }

    return (memosJson.length, genresJson.length);
  }

  Future<Directory> _voiceMemosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'voice_memos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
