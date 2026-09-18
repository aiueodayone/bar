import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_app/data/genre_repository.dart';
import 'package:memo_app/data/memo_repository.dart';
import 'package:memo_app/models/genre.dart';
import 'package:memo_app/models/memo.dart';
import 'package:memo_app/services/backup_service.dart';

import 'support/db_test_utils.dart';

/// テスト中だけ getApplicationDocumentsDirectory() を一時ディレクトリに
/// 差し替える。実機・エミュレータなしで path_provider のプラットフォーム
/// チャンネルを叩かせないようにするため。
class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('temoto_backup_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    await clearMemoDatabase();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('createBackupBytes → restoreFromBackup round-trips genres and memos '
      'through the real AES-GCM encryption and a real (in-memory-ish) sqlite '
      'database, exactly like the on-device path does', () async {
    final memoRepository = MemoRepository();
    final genreRepository = GenreRepository();

    final genre = Genre(id: 'g1', name: '仕事', color: Colors.teal);
    await genreRepository.upsertGenre(genre, sortOrder: 0);

    final memo = Memo(
      id: 'm1',
      title: 'テストメモ',
      content: 'これは復元テスト用の内容です',
      genreId: 'g1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await memoRepository.upsertMemo(memo);

    final service = BackupService(
      memoRepository: memoRepository,
      genreRepository: genreRepository,
    );

    final (bytes, fileName) = await service.createBackupBytes();

    expect(fileName, endsWith('.zip'));
    // 暗号化されているので、平文のタイトル文字列がバイト列にそのまま
    // 出てきてはいけない(=正しく暗号化されていることの確認)。
    expect(
      String.fromCharCodes(bytes.where((b) => b < 128)),
      isNot(contains('m1')),
    );

    final (memoCount, genreCount) = await service.restoreFromBackup(bytes);

    expect(memoCount, 1);
    expect(genreCount, 1);

    final restoredMemo = await memoRepository.fetchMemoById('m1');
    expect(restoredMemo, isNotNull);
    expect(restoredMemo!.title, 'テストメモ');
    expect(restoredMemo.content, 'これは復元テスト用の内容です');

    final restoredGenres = await genreRepository.fetchGenres();
    expect(restoredGenres.map((g) => g.id), contains('g1'));
  });

  test('a memo with an audio recording round-trips through backup/restore '
      'with the same audio bytes intact', () async {
    final memoRepository = MemoRepository();
    final genreRepository = GenreRepository();

    // 元の録音ファイルは、復元先(voice_memos/)とは別の場所に置く。
    // そうしないと「たまたま同じパスのまま」で通ってしまい、実際に
    // バイト列がコピーされたことの確認にならない。
    final sourceDir = await Directory('${tempDir.path}/original_recordings')
        .create(recursive: true);
    final originalAudioFile = File('${sourceDir.path}/voice_test.wav');
    final audioBytes = List<int>.generate(200, (i) => i % 256);
    await originalAudioFile.writeAsBytes(audioBytes);

    final memo = Memo(
      id: 'm-audio',
      title: '音声メモ',
      content: '',
      audioPath: originalAudioFile.path,
      audioDurationMs: 4200,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await memoRepository.upsertMemo(memo);

    final service = BackupService(
      memoRepository: memoRepository,
      genreRepository: genreRepository,
    );
    final (bytes, _) = await service.createBackupBytes();

    // 復元前に元の録音を削除し、バックアップの中身から本当に
    // 復元されていることを確認する(元ファイルが残っていて
    // たまたま一致して見える、という誤検知を避ける)。
    await originalAudioFile.delete();
    await memoRepository.deleteMemo('m-audio');

    await service.restoreFromBackup(bytes);

    final restoredMemo = await memoRepository.fetchMemoById('m-audio');
    expect(restoredMemo, isNotNull);
    expect(restoredMemo!.hasAudio, isTrue);
    expect(restoredMemo.audioDurationMs, 4200);

    final restoredAudioFile = File(restoredMemo.audioPath!);
    expect(await restoredAudioFile.exists(), isTrue);
    expect(await restoredAudioFile.readAsBytes(), audioBytes);
  });
}
