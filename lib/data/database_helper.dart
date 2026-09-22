import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// アプリ内で使用する SQLite データベースを管理するシングルトン。
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'memo_app.db';
  static const int _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final db = await _open();
    _db = db;
    return db;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // テスト環境(sqflite_common_ffi)では各テストファイルが別プロセス
        // として同じディスク上の DB ファイルを開くため、同時書き込みが
        // 稀に SQLITE_BUSY("database is locked")で即座に失敗することが
        // ある。busy_timeout を設定し、ロックが空くまで少し待ってから
        // 再試行させることでこれを避ける(実機の sqflite でも無害)。
        await db.execute('PRAGMA busy_timeout = 5000');
      },
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
        await db.execute('CREATE INDEX idx_memos_genre ON memos (genre_id)');
        await db.execute(
          'CREATE INDEX idx_memos_updated_at ON memos (updated_at DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_memos_deleted_at ON memos (deleted_at)',
        );
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
        await db.execute(
          'CREATE INDEX idx_memo_images_memo_id ON memo_images (memo_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ごみ箱(削除済みボックス)機能のために deleted_at 列を追加する。
        // NULL = 通常のメモ、非NULL = ごみ箱に入っている(その時刻に削除)。
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE memos ADD COLUMN deleted_at INTEGER');
          await db.execute(
            'CREATE INDEX idx_memos_deleted_at ON memos (deleted_at)',
          );
        }
        // 画像添付機能のために memo_images テーブルを追加する。
        if (oldVersion < 3) {
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
          await db.execute(
            'CREATE INDEX idx_memo_images_memo_id ON memo_images (memo_id)',
          );
        }
      },
    );
  }
}
