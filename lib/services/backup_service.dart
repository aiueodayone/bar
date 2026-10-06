import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;
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

/// [compute] に渡す ZIP 内の1エントリ(元ファイルのパスと、ZIP内でのパス)。
/// 以前はここでファイルのバイト列そのものを保持していたが、添付が多い
/// (特に動画)と、全ファイル分のバイト列をメインisolateで読み込んで
/// 保持 → isolateをまたいでコピー → さらにZIP全体をメモリ上に
/// エンコード、という3重のメモリコピーが発生し、蓄積データが多いほど
/// メモリを圧迫する作りになっていた。パスだけを渡し、実際のファイル
/// 読み込みはisolate内で [ZipFileEncoder] に1ファイルずつストリーミング
/// させることで、どの時点でも「今処理中の1ファイル分」程度のメモリしか
/// 使わないようにする。
class _ZipPathEntry {
  const _ZipPathEntry(this.sourcePath, this.zipPath);
  final String sourcePath;
  final String zipPath;
}

class _CreateZipArgs {
  const _CreateZipArgs(this.entries, this.jsonBytes, this.outputZipPath);
  final List<_ZipPathEntry> entries;
  final Uint8List jsonBytes;

  /// ZIPを一旦書き出す一時ファイルのパス(メインisolateで
  /// getTemporaryDirectory() を使って解決したものを渡す。path_provider の
  /// プラットフォームチャンネル呼び出しはバックグラウンドisolateからは
  /// 使えないため)。
  final String outputZipPath;
}

/// [compute] 用トップレベル関数: ZIP圧縮(今はストリーミングで実質
/// 無圧縮)とAES-GCM暗号化はいずれもバックアップ対象のファイルサイズに
/// 比例して重くなる処理で、動画添付を含むバックアップではメインisolate
/// (=UIスレッド)上で実行すると体感できるフリーズを起こしうる。まとめて
/// バックグラウンドisolateで行う。
///
/// トップレベル関数(またはstaticメソッド)である必要がある: compute() は
/// 関数そのものを別isolateに渡して実行するため、クロージャやインスタンス
/// メソッドは使えない。_backupEncryptionKeyBytes 等のトップレベル定数は
/// 同じプログラムが読み込まれた新しいisolateでもそのまま参照できるため、
/// 引数として渡す必要はない。
Future<Uint8List> _buildEncryptedBackupZip(_CreateZipArgs args) async {
  final encoder = ZipFileEncoder();
  encoder.create(args.outputZipPath);
  try {
    for (final entry in args.entries) {
      final file = File(entry.sourcePath);
      if (!await file.exists()) continue;
      // 写真・動画・音声はすでに圧縮済み形式なので、ZIP側でさらに
      // 圧縮(DEFLATE)をかけてもファイルサイズはほとんど縮まらず、
      // CPU時間だけ余分にかかる。STORE(無圧縮)で素通しする。
      await encoder.addFile(file, entry.zipPath, ZipFileEncoder.STORE);
    }
    encoder.addArchiveFile(
      ArchiveFile('backup.json', args.jsonBytes.length, args.jsonBytes),
    );
  } finally {
    await encoder.close();
  }

  final zipFile = File(args.outputZipPath);
  final zipBytes = await zipFile.readAsBytes();
  try {
    await zipFile.delete();
  } catch (_) {
    // 一時ファイルの削除失敗は致命的ではない(OSのキャッシュ領域なので
    // いずれ回収される)。バックアップ作成自体は続行する。
  }

  final secretKey = SecretKey(_backupEncryptionKeyBytes);
  final secretBox = await AesGcm.with256bits().encrypt(
    zipBytes,
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

class _DecryptArgs {
  const _DecryptArgs(this.cipherText, this.nonce, this.mac);
  final Uint8List cipherText;
  final Uint8List nonce;
  final Uint8List mac;
}

/// [compute] 用トップレベル関数: AES-GCM復号本体(重い部分)だけを
/// バックグラウンドisolateに任せる。ヘッダ解析やバージョンチェックは
/// 軽い処理なので [BackupService._decryptBytes] 側(メインisolate)で行う。
Future<Uint8List> _decryptCipherText(_DecryptArgs args) async {
  final secretKey = SecretKey(_backupEncryptionKeyBytes);
  final secretBox = SecretBox(
    args.cipherText,
    nonce: args.nonce,
    mac: Mac(args.mac),
  );
  final plainBytes = await AesGcm.with256bits().decrypt(
    secretBox,
    secretKey: secretKey,
  );
  return Uint8List.fromList(plainBytes);
}

class _ExtractArgs {
  const _ExtractArgs(this.zipBytes, this.stagingDirPath);
  final Uint8List zipBytes;
  final String stagingDirPath;
}

class _ExtractResult {
  const _ExtractResult(this.jsonBytes, this.extractedPaths);

  /// backup.json の中身。見つからなければ null(バックアップとして
  /// 不正なファイル)。
  final Uint8List? jsonBytes;

  /// ZIP内パス(例: 'images/xxx.jpg')→ 一時展開先の実ファイルパス。
  final Map<String, String> extractedPaths;
}

/// [compute] 用トップレベル関数: ZIP展開(解凍)も元ファイルサイズに比例して
/// 重い処理なので、バックグラウンドisolateで行う。
///
/// 以前は展開した全ファイルの中身を `Map<String, Uint8List>` としてまとめて
/// メインisolateに返していたが、これだと「添付ファイル全部ぶんのバイト列を
/// 一度に保持する」状態になり、蓄積データが多いバックアップほどメモリを
/// 圧迫する。1ファイルずつ一時ディレクトリに書き出すことで、どの時点でも
/// 「今処理中の1ファイル分」程度のメモリしか使わないようにする。
/// メインisolate側は、このステージング先から実際の保存先へ
/// File.rename()(同一ファイルシステム上ならOSレベルの移動で、Dartの
/// メモリを経由しない)するだけでよい。
Future<_ExtractResult> _extractBackupZip(_ExtractArgs args) async {
  final archive = ZipDecoder().decodeBytes(args.zipBytes);
  Uint8List? jsonBytes;
  final extracted = <String, String>{};

  for (final file in archive.files) {
    if (!file.isFile) continue;
    if (file.name == 'backup.json') {
      jsonBytes = Uint8List.fromList(file.content as List<int>);
      continue;
    }
    final outFile = File(p.join(args.stagingDirPath, file.name));
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(file.content as List<int>);
    extracted[file.name] = outFile.path;
  }

  return _ExtractResult(jsonBytes, extracted);
}

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

    final zipEntries = <_ZipPathEntry>[];
    final audioFileByMemoId = <String, String>{};
    final imagesByMemoId = <String, List<Map<String, Object?>>>{};

    for (final memo in memos) {
      if (!memo.hasAudio) continue;
      final file = File(memo.audioPath!);
      if (!await file.exists()) continue;
      final zipPath = 'audio/${p.basename(memo.audioPath!)}';
      zipEntries.add(_ZipPathEntry(memo.audioPath!, zipPath));
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
        zipEntries.add(_ZipPathEntry(image.path, zipPath));
        entries.add({
          'file': zipPath,
          'sortOrder': image.sortOrder,
          'type': image.type.name,
        });
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
            'isFavorite': memo.isFavorite,
          },
      ],
    };

    final jsonBytes = utf8.encode(jsonEncode(data));

    // getTemporaryDirectory() は path_provider のプラットフォームチャンネル
    // 呼び出しなのでメインisolateで解決し、パス文字列だけをisolateに渡す。
    final tmpDir = await getTemporaryDirectory();
    final tmpZipPath = p.join(
      tmpDir.path,
      'backup_build_${DateTime.now().microsecondsSinceEpoch}.zip',
    );

    // ZIP圧縮とAES暗号化はバックグラウンドisolateにまとめて任せる
    // (_buildEncryptedBackupZip 参照)。
    final encrypted = await compute(
      _buildEncryptedBackupZip,
      _CreateZipArgs(zipEntries, Uint8List.fromList(jsonBytes), tmpZipPath),
    );
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

    // getTemporaryDirectory() はメインisolateで解決し、パス文字列だけを
    // isolateに渡す(path_provider はバックグラウンドisolateから直接は
    // 使えないため)。
    final tmpDir = await getTemporaryDirectory();
    final stagingDirPath = p.join(
      tmpDir.path,
      'restore_staging_${DateTime.now().microsecondsSinceEpoch}',
    );

    // ZIP展開もバックグラウンドisolateで行う(_extractBackupZip 参照)。
    // 添付ファイルは1つずつ一時ディレクトリに書き出すだけで、全ファイル分
    // のバイト列をまとめてメモリに保持することはない。
    final _ExtractResult result;
    try {
      result = await compute(
        _extractBackupZip,
        _ExtractArgs(zipBytes, stagingDirPath),
      );
    } catch (_) {
      await _deleteDirectoryIfExists(stagingDirPath);
      throw const InvalidBackupFileException('このファイルはバックアップとして読み取れませんでした');
    }

    final jsonBytesEntry = result.jsonBytes;
    if (jsonBytesEntry == null) {
      await _deleteDirectoryIfExists(stagingDirPath);
      throw const InvalidBackupFileException('このファイルは手もとメモのバックアップではないようです');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(jsonBytesEntry)) as Map<String, dynamic>;
    } catch (_) {
      await _deleteDirectoryIfExists(stagingDirPath);
      throw const InvalidBackupFileException('バックアップファイルの内容を読み取れませんでした');
    }

    try {
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
          final stagedPath = result.extractedPaths[audioFileInZip];
          if (stagedPath != null) {
            final outPath = p.join(audioDir.path, p.basename(audioFileInZip));
            await _moveStagedFile(stagedPath, outPath);
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
          // お気に入り機能を追加する前のバックアップには無い項目なので、
          // 無ければ false 扱いにする。
          isFavorite: memoMap['isFavorite'] as bool? ?? false,
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
          final stagedPath = result.extractedPaths[fileInZip];
          if (stagedPath == null) continue;
          final outPath = p.join(imagesDir.path, p.basename(fileInZip));
          await _moveStagedFile(stagedPath, outPath);
          await _imageRepository.insertImage(
            MemoImage(
              id: p.basenameWithoutExtension(fileInZip),
              memoId: memoId,
              path: outPath,
              sortOrder: imageMap['sortOrder'] as int? ?? i,
              createdAt: DateTime.now(),
              type: MemoAttachmentType.fromName(
                imageMap['type'] as String? ?? 'image',
              ),
            ),
          );
        }
      }

      return (memosJson.length, genresJson.length);
    } finally {
      // 展開済みファイルは移動(rename)済みのはずだが、対応するメモが
      // JSON に無かったものなどが残っている可能性もあるので、
      // 一時ディレクトリごと必ず掃除する。
      await _deleteDirectoryIfExists(stagingDirPath);
    }
  }

  /// 一時展開先から実際の保存先へファイルを移す。同一ファイルシステム上
  /// なら rename はOSレベルのメタデータ操作だけで完了し、Dartのメモリを
  /// 経由しない(file_picker 経由で選んだバックアップ ZIP の展開先と、
  /// アプリの保存領域は通常どちらも端末内部ストレージの同じ
  /// ファイルシステム上にあるため、これで十分なはず)。万が一 rename が
  /// 使えない環境向けに、コピー+削除にフォールバックする。
  Future<void> _moveStagedFile(String stagedPath, String outPath) async {
    try {
      await File(stagedPath).rename(outPath);
    } catch (_) {
      await File(stagedPath).copy(outPath);
      try {
        await File(stagedPath).delete();
      } catch (_) {
        // 消せなくても無視する(後で一時ディレクトリごと掃除される)。
      }
    }
  }

  Future<void> _deleteDirectoryIfExists(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // 掃除に失敗しても復元自体は成功しているので無視する。
      }
    }
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
  ///
  /// ヘッダ解析・バージョンチェックは軽い処理なのでここ(メインisolate)で
  /// 行い、重いAES-GCM復号本体だけ [_decryptCipherText] としてバック
  /// グラウンドisolateに任せる。
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

      return await compute(
        _decryptCipherText,
        _DecryptArgs(cipherText, nonce, mac),
      );
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
