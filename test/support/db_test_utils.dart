import 'package:memo_app/data/database_helper.dart';
import 'package:memo_app/data/genre_repository.dart';
import 'package:memo_app/data/memo_repository.dart';

/// sqflite_common_ffi はテスト実行のたびに使い捨てられるインメモリDBでは
/// なく、ディスク上の実ファイルを開く。[dbHelper] には各テストファイルが
/// 専用に作った [DatabaseHelper.forTesting] を渡すこと(共有の
/// [DatabaseHelper.instance] を複数のテストファイルが並行して使うと、
/// flutter test がテストファイルを別プロセスとして並行実行する都合上、
/// SQLITE_BUSY で失敗することがあるため)。
/// 各テストの頭でこれを呼び、まっさらな状態から始める。
Future<void> clearMemoDatabase(DatabaseHelper dbHelper) async {
  final memoRepository = MemoRepository(dbHelper: dbHelper);
  final genreRepository = GenreRepository(dbHelper: dbHelper);

  for (final memo in await memoRepository.fetchMemos()) {
    await memoRepository.deleteMemo(memo.id);
  }
  for (final memo in await memoRepository.fetchTrashedMemos()) {
    await memoRepository.deleteMemo(memo.id);
  }
  for (final genre in await genreRepository.fetchGenres()) {
    await genreRepository.deleteGenre(genre.id);
  }
}
