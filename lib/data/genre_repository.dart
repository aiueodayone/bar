import '../models/genre.dart';
import 'database_helper.dart';

/// ジャンル(カテゴリ)の永続化を担うリポジトリ。
class GenreRepository {
  GenreRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<Genre>> fetchGenres() async {
    final db = await _dbHelper.database;
    final rows = await db.query('genres', orderBy: 'sort_order ASC');
    return rows.map(Genre.fromMap).toList();
  }

  Future<void> upsertGenre(Genre genre, {int sortOrder = 0}) async {
    final db = await _dbHelper.database;
    await db.insert('genres', {
      ...genre.toMap(),
      'sort_order': sortOrder,
    });
  }

  Future<void> updateGenre(Genre genre) async {
    final db = await _dbHelper.database;
    await db.update(
      'genres',
      genre.toMap(),
      where: 'id = ?',
      whereArgs: [genre.id],
    );
  }

  Future<void> deleteGenre(String id) async {
    final db = await _dbHelper.database;
    await db.delete('genres', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> nextSortOrder() async {
    final db = await _dbHelper.database;
    final result =
        await db.rawQuery('SELECT MAX(sort_order) AS m FROM genres');
    final max = result.first['m'] as int?;
    return (max ?? -1) + 1;
  }
}
