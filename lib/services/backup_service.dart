import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/genre_repository.dart';
import '../data/memo_image_repository.dart';
import '../data/memo_repository.dart';
import '../models/genre.dart';
import '../models/memo.dart';
import '../models/memo_image.dart';

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

/// バックアップの中身(メモの文面や録音)をそのまま覗き見できないように
/// するための固定鍵。ユーザーにパスワードを求めない代わりに、アプリに
/// 埋め込まれたこの鍵で自動的に暗号化・復号する。
///
/// 注意: この鍵はアプリ本体に同梱されているため、アプリを解析すれば
/// 取り出せてしまう。これは「クラウドストレージに置いた際に、たまたま
/// アクセスできた他人がバックアップの JSON をそのまま読めてしまう」
/// ような偶発的な閲覧を防ぐための軽い保護であり、本気で狙われた場合の
/// 秘匿性まで保証するものではない。
const List<int> _backupEncryptionKeyBytes = [
  0x89,
  0x1b,
  0x3d,
  0x11,
  0x7e,
  0x70,
  0xe0,
  0xc3,
  0xf6,
  0x48,
  0xa1,
  0x9a,
  0x6e,
  0x4c,
  0x22,
  0xee,
  0x8f,
  0xc0,
  0xc6,
  0x6e,
  0xbd,
  0xbf,
  0x6f,
  0x3c,
  0x0f,
  0x11,
  0xf1,
  0x21,
  0x24,
  0x89,
  0x76,
  0x47,
];

/// 暗号化バックアップの先頭に付けるマジックバイト列 ("TMEB" =
/// TeMoto-memo Encrypted Backup)。この4バイトで、暗号化前の旧形式の
/// 素の ZIP (先頭は常に "PK")と区別する。
const List<int> _encryptedBackupMagic = [0x54, 0x4D, 0x45, 0x42];
const int _encryptionFormatVersion = 1;

/// メモ・ジャンル・録音データをまとめてバックアップ/復元するサービス。
///
/// バックアップの中身は ZIP ファイル1つにまとめる: メモ・ジャンルの
/// データは backup.json、録音ファイルは audio/ フォルダ以下にそのまま
/// 含める。この ZIP 全体を、アプリに埋め込まれた固定鍵で AES-256-GCM
/// 暗号化してから保存する(ユーザーにパスワードの入力・管理を求めない)。
///
/// 復元は既存データを削除せず、同じ ID のものは上書き、無いものは追加する
/// (マージ)。誤って新しいメモを消してしまうことがないようにするため。
class BackupService {
  BackupService({
    MemoRepository? memoRepository,
    GenreRepository? genreRepository,
    MemoImageRepository? imageRepository,
  }) : _memoRepository = memoRepository ?? MemoRepository(),
       _genreRepository = genreRepository ?? GenreRepository(),
       _imageRepository = imageRepository ?? MemoImageRepository();

  final MemoRepository _memoRepository;
  final GenreRepository _genreRepository;
  final MemoImageRepository _imageRepository;

  /// 全メモ・ジャンル・録音ファイルをまとめた暗号化済みバックアップを
  /// 作成し、そのバイト列とファイル名を返す。
  ///
  /// 共有シート(share_plus)は使わない: LINE や SNS などの「送信先」も
  /// 選択肢に並んでしまい、誤ってメモの中身を他人に送ってしまうリスクが
  /// ある。呼び出し側では代わりに `FilePicker.saveFile()`
  /// (Android の ACTION_CREATE_DOCUMENT = 「保存先を選ぶ」ダイアログ)を
  /// 使うこと。これは Google ドライブや端末のストレージなど保存先のみが
  /// 並ぶ SAF の仕組みで、LINE 等のメッセージアプリは
  /// DocumentsProvider を実装していないため選択肢に出てこない。
  Future<(Uint8List, String)> createBackupBytes() async {
    final genres = await _genreRepository.fetchGenres();
    final memos = await _memoRepository.fetchMemos();

    final archive = Archive();
    final audioFileByMemoId = <String, String>{};
    final imagesByMemoId = <String, List<Map<String, Object?>>>{};

    for (final memo in memos) {
      if (!memo.hasAudio) continue;
      final file = File(memo.audioPath!);
      if (!await file.exists()) continue;
      final zipPath = 'audio/${p.basename(memo.audioPath!)}';
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
      audioFileByMemoId[memo.id] = zipPath;
    }

    for (final memo in memos) {
      final images = await _imageRepository.fetchImagesForMemo(memo.id);
      if (images.isEmpty) continue;
      final entries = <Map<String, Object?>>[];
      for (final image in images) {
        final file = File(image.path);
        if (!await file.exists()) continue;
        final zipPath = 'images/${image.id}${p.extension(image.path)}';
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(zipPath, bytes.length, bytes));
        entries.add({'file': zipPath, 'sortOrder': image.sortOrder});
      }
      if (entries.isNotEmpty) {
        imagesByMemoId[memo.id] = entries;
      }
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
            'images': imagesByMemoId[memo.id] ?? const [],
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

    final encrypted = await _encryptBytes(zipBytes);
    // 拡張子は .zip のままにする(中身はもう valid な zip ではないが)。
    // Android の保存/選択ダイアログは .tmbackup のような独自拡張子だと
    // MIME タイプを解決できず、保存時にファイル名が化けたり、復元時の
    // ファイル選択ダイアログに出てこなくなったりすることがあるため、
    // OS 全体が確実に認識できる .zip を使うほうが安全。
    final fileName =
        'temotomemo_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    return (encrypted, fileName);
  }

  /// バックアップファイル(のバイト列)からメモ・ジャンル・録音データを
  /// 復元する。戻り値は (復元したメモ件数, 復元したジャンル件数)。
  ///
  /// ファイルパスではなくバイト列を受け取る: Android では file_picker が
  /// 選択結果を `content://` の URI で返すことがあり、その場合
  /// `PlatformFile.path` は null になるため、常に `readAsBytes()` 経由で
  /// 読み込む方が確実。
  ///
  /// 暗号化前の旧バージョンで作られた素の ZIP バックアップもそのまま
  /// 復元できる(マジックバイトが無ければ暗号化されていないとみなす)。
  Future<(int, int)> restoreFromBackup(Uint8List bytes) async {
    final zipBytes = _looksEncrypted(bytes)
        ? await _decryptBytes(bytes)
        : bytes;

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
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
    final imagesDir = await _memoImagesDirectory();
    final memosJson = (data['memos'] as List<dynamic>?) ?? const [];
    for (final entry in memosJson) {
      final memoMap = entry as Map<String, dynamic>;
      final memoId = memoMap['id'] as String;
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
        id: memoId,
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

      // このメモの画像は、バックアップの内容で洗い替える(復元前に既に
      // 付いていた画像は一旦すべて消してから、バックアップの内容を
      // 入れ直す)。
      await _imageRepository.deleteImagesForMemo(memoId);
      final imagesJson = (memoMap['images'] as List<dynamic>?) ?? const [];
      for (var i = 0; i < imagesJson.length; i++) {
        final imageMap = imagesJson[i] as Map<String, dynamic>;
        final fileInZip = imageMap['file'] as String?;
        if (fileInZip == null) continue;
        final match = archive.files.where((f) => f.name == fileInZip);
        if (match.isEmpty) continue;
        final outPath = p.join(imagesDir.path, p.basename(fileInZip));
        await File(outPath).writeAsBytes(match.first.content as List<int>);
        await _imageRepository.insertImage(
          MemoImage(
            id: p.basenameWithoutExtension(fileInZip),
            memoId: memoId,
            path: outPath,
            sortOrder: imageMap['sortOrder'] as int? ?? i,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return (memosJson.length, genresJson.length);
  }

  bool _looksEncrypted(Uint8List bytes) {
    if (bytes.length < _encryptedBackupMagic.length) return false;
    for (var i = 0; i < _encryptedBackupMagic.length; i++) {
      if (bytes[i] != _encryptedBackupMagic[i]) return false;
    }
    return true;
  }

  /// コンテナ形式: マジック(4) + フォーマットバージョン(1) + nonce(12) +
  /// MAC(16) + 暗号文。固定鍵なので salt は不要。
  Future<Uint8List> _encryptBytes(List<int> plainBytes) async {
    final secretKey = SecretKey(_backupEncryptionKeyBytes);
    final secretBox = await AesGcm.with256bits().encrypt(
      plainBytes,
      secretKey: secretKey,
    );

    return Uint8List.fromList([
      ..._encryptedBackupMagic,
      _encryptionFormatVersion,
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ]);
  }

  Future<Uint8List> _decryptBytes(Uint8List bytes) async {
    try {
      var offset = _encryptedBackupMagic.length;
      final version = bytes[offset];
      offset += 1;
      if (version != _encryptionFormatVersion) {
        throw UnsupportedBackupVersionException(
          'このバックアップ(暗号化形式バージョン $version)は、お使いのアプリより'
          '新しい形式です。アプリを最新版に更新してからお試しください。',
        );
      }

      const nonceLength = 12;
      const macLength = 16;
      final nonce = bytes.sublist(offset, offset + nonceLength);
      offset += nonceLength;
      final mac = bytes.sublist(offset, offset + macLength);
      offset += macLength;
      final cipherText = bytes.sublist(offset);

      final secretKey = SecretKey(_backupEncryptionKeyBytes);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final plainBytes = await AesGcm.with256bits().decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(plainBytes);
    } on UnsupportedBackupVersionException {
      rethrow;
    } catch (_) {
      throw const InvalidBackupFileException('バックアップファイルの内容を読み取れませんでした');
    }
  }

  Future<Directory> _voiceMemosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'voice_memos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _memoImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'memo_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
