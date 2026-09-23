import 'package:sqflite/sqflite.dart';

import '../models/memo.dart';
import '../utils/kana.dart';
import 'database_helper.dart';

/// メモの永続化(検索・ジャンル絞り込みを含む)を担うリポジトリ。
class MemoRepository {
  MemoRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// ごみ箱に入っている(deleted_at が非NULLの)メモは含まない。
  Future<List<Memo>> fetchMemos({
    String? genreId,
    String searchQuery = '',
  }) async {
    final db = await _dbHelper.database;
    final where = <String>['deleted_at IS NULL'];
    final args = <Object?>[];

    if (genreId == 'unassigned') {
      where.add('genre_id IS NULL');
    } else if (genreId != null) {
      where.add('genre_id = ?');
      args.add(genreId);
    }

    final rows = await db.query(
      'memos',
      where: where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
    );
    var memos = rows.map(Memo.fromMap).toList();

    // ひらがな・カタカナを区別せず検索できるよう、SQLの LIKE ではなく
    // 正規化した文字列同士を Dart 側で比較する(メモ数はSQLiteに任せる
    // 規模ではないので、性能上の問題にはならない)。
    final trimmed = searchQuery.trim();
    if (trimmed.isNotEmpty) {
      final normalizedQuery = normalizeForSearch(trimmed);
      memos = memos.where((memo) {
        return normalizeForSearch(memo.title).contains(normalizedQuery) ||
            normalizeForSearch(memo.content).contains(normalizedQuery);
      }).toList();
    }

    return memos;
  }

  /// ごみ箱に入っているメモを、削除日時が新しい順に返す。
  Future<List<Memo>> fetchTrashedMemos() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'memos',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(Memo.fromMap).toList();
  }

  /// [cutoff] より前にごみ箱入りしたメモ(保存期限切れ)を返す。
  Future<List<Memo>> fetchExpiredTrash(DateTime cutoff) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'memos',
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
    return rows.map(Memo.fromMap).toList();
  }

  Future<Memo?> fetchMemoById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('memos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Memo.fromMap(rows.first);
  }

  Future<void> upsertMemo(Memo memo) async {
    final db = await _dbHelper.database;
    // ConflictAlgorithm.replace は使わない。既存行との主キー衝突時、
    // SQLite は「UPDATE」ではなく実際には「既存行を DELETE してから
    // INSERT」で処理するため、memo_images の
    // "FOREIGN KEY (memo_id) REFERENCES memos (id) ON DELETE CASCADE"
    // が発火し、そのメモに添付した画像・動画の行が保存のたびに毎回
    // 消えてしまう(実機で「写真・動画を追加すると前のものが消える/
    // 上書きされる」という報告の実際の原因だった)。既存行があれば
    // UPDATE、なければ INSERT にすることで、行を削除せずに更新し、
    // カスケード削除を発火させない。
    final updated = await db.update(
      'memos',
      memo.toMap(),
      where: 'id = ?',
      whereArgs: [memo.id],
    );
    if (updated == 0) {
      await db.insert('memos', memo.toMap());
    }
  }

  /// ごみ箱に移動する(deleted_at をセットするだけで、行は残す)。
  Future<void> softDeleteMemos(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'memos',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// ごみ箱から元に戻す(deleted_at を NULL に戻す)。
  Future<void> restoreMemo(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'memos',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 行そのものを完全に削除する。ごみ箱からの完全削除・保存期限切れの
  /// 自動削除の両方で使う。
  Future<void> deleteMemo(String id) async {
    final db = await _dbHelper.database;
    await db.delete('memos', where: 'id = ?', whereArgs: [id]);
  }

  /// ごみ箱に入っているものは数えない。
  Future<int> countByGenre(String genreId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM memos WHERE genre_id = ? AND deleted_at IS NULL',
      [genreId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
