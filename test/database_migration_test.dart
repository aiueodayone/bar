import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_app/data/database_helper.dart';

/// これまでのテストは、すべて新規インストール相当(onCreate だけが
/// 走る、まっさらなファイル)しか検証していなかった。実際にユーザーの
/// 端末で起きるのは「既存アプリをアップデートしてonUpgradeが走る」
/// ケースであり、そこは一度もテストしていなかった。
///
/// このファイルでは、過去の各バージョンのスキーマを手で再現した
/// ファイルを用意し、そこに DatabaseHelper の実際の onUpgrade を
/// 適用して、例外なく完走すること・データが残ること・新しい列が
/// ちゃんと使えることを確認する。
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<String> pathFor(String name) async {
    final dir = await databaseFactory.getDatabasesPath();
    return p.join(dir, name);
  }

  Future<void> reset(String path) async {
    await databaseFactory.deleteDatabase(path);
  }

  test('upgrading from version 1 (pre-trash, pre-images) to version 4 '
      'succeeds and preserves existing memos', () async {
    final path = await pathFor('test_migration_v1.db');
    await reset(path);

    // v1 時点のスキーマを手で再現する(deleted_at も memo_images も無い)。
    final oldDb = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE genres (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE memos (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              genre_id TEXT,
              audio_path TEXT,
              audio_duration_ms INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              FOREIGN KEY (genre_id) REFERENCES genres (id) ON DELETE SET NULL
            )
          ''');
        },
      ),
    );
    await oldDb.insert('memos', {
      'id': 'old-memo-1',
      'title': '移行前からあるメモ',
      'content': '内容',
      'genre_id': null,
      'audio_path': null,
      'audio_duration_ms': null,
      'created_at': 1000,
      'updated_at': 1000,
    });
    await oldDb.close();

    // ここで実際の DatabaseHelper(version 4)で同じファイルを開く。
    // v1→v4 への onUpgrade が実際に走る。
    final dbHelper = DatabaseHelper.forTesting('test_migration_v1.db');
    final db = await dbHelper.database;

    // 例外を投げずに開けたことに加え、期待する列が揃っているか確認する。
    final memosColumns = (await db.rawQuery(
      'PRAGMA table_info(memos)',
    )).map((r) => r['name'] as String).toSet();
    expect(memosColumns, contains('deleted_at'));

    final imagesColumns = (await db.rawQuery(
      'PRAGMA table_info(memo_images)',
    )).map((r) => r['name'] as String).toSet();
    expect(imagesColumns, containsAll(['path', 'sort_order', 'type']));

    // 以前からあったメモが消えずに残っていること。
    final rows = await db.query(
      'memos',
      where: 'id = ?',
      whereArgs: ['old-memo-1'],
    );
    expect(rows, hasLength(1));
    expect(rows.first['title'], '移行前からあるメモ');

    // 新しい列を実際に使って書き込めること(型不整合等が無いか)。
    await db.insert('memo_images', {
      'id': 'img-after-migration',
      'memo_id': 'old-memo-1',
      'path': '/tmp/x.jpg',
      'sort_order': 0,
      'created_at': 2000,
      'type': 'video',
    });
    final imageRows = await db.query('memo_images');
    expect(imageRows.single['type'], 'video');
  });

  test('upgrading from version 2 (has deleted_at, no memo_images) to '
      'version 4 succeeds', () async {
    final path = await pathFor('test_migration_v2.db');
    await reset(path);

    final oldDb = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE genres (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE memos (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              genre_id TEXT,
              audio_path TEXT,
              audio_duration_ms INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER,
              FOREIGN KEY (genre_id) REFERENCES genres (id) ON DELETE SET NULL
            )
          ''');
        },
      ),
    );
    await oldDb.close();

    final dbHelper = DatabaseHelper.forTesting('test_migration_v2.db');
    final db = await dbHelper.database;

    final imagesColumns = (await db.rawQuery(
      'PRAGMA table_info(memo_images)',
    )).map((r) => r['name'] as String).toSet();
    expect(imagesColumns, containsAll(['path', 'sort_order', 'type']));
  });

  test('upgrading from version 3 (has memo_images without a type column) '
      'to version 4 succeeds and defaults existing rows to image', () async {
    final path = await pathFor('test_migration_v3.db');
    await reset(path);

    final oldDb = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE genres (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE memos (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              genre_id TEXT,
              audio_path TEXT,
              audio_duration_ms INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER,
              FOREIGN KEY (genre_id) REFERENCES genres (id) ON DELETE SET NULL
            )
          ''');
          // v3 時点の memo_images: type 列はまだ無い。
          await db.execute('''
            CREATE TABLE memo_images (
              id TEXT PRIMARY KEY,
              memo_id TEXT NOT NULL,
              path TEXT NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              FOREIGN KEY (memo_id) REFERENCES memos (id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );
    await oldDb.insert('memos', {
      'id': 'memo-v3',
      'title': 'v3のメモ',
      'content': '',
      'created_at': 1000,
      'updated_at': 1000,
    });
    await oldDb.insert('memo_images', {
      'id': 'img-v3',
      'memo_id': 'memo-v3',
      'path': '/tmp/existing.jpg',
      'sort_order': 0,
      'created_at': 1000,
    });
    await oldDb.close();

    final dbHelper = DatabaseHelper.forTesting('test_migration_v3.db');
    final db = await dbHelper.database;

    final rows = await db.query(
      'memo_images',
      where: 'id = ?',
      whereArgs: ['img-v3'],
    );
    expect(rows, hasLength(1));
    // 既存行は type 列が無い状態から追加されたので、デフォルト値の
    // 'image' になっているはず。
    expect(rows.first['type'], 'image');
  });
}
