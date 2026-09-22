import 'package:sqflite/sqflite.dart';

import '../models/memo_image.dart';
import 'database_helper.dart';

/// メモに添付された画像(memo_images テーブル)の永続化を担うリポジトリ。
class MemoImageRepository {
  MemoImageRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<MemoImage>> fetchImagesForMemo(String memoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'memo_images',
      where: 'memo_id = ?',
      whereArgs: [memoId],
      orderBy: 'sort_order ASC',
    );
    return rows.map(MemoImage.fromMap).toList();
  }

  Future<void> insertImage(MemoImage image) async {
    final db = await _dbHelper.database;
    await db.insert(
      'memo_images',
      image.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteImage(String id) async {
    final db = await _dbHelper.database;
    await db.delete('memo_images', where: 'id = ?', whereArgs: [id]);
  }

  /// 指定したメモの画像行をすべて削除する(バックアップ復元時、復元前の
  /// 状態を洗い替えるために使う)。
  Future<void> deleteImagesForMemo(String memoId) async {
    final db = await _dbHelper.database;
    await db.delete('memo_images', where: 'memo_id = ?', whereArgs: [memoId]);
  }
}
