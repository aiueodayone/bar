import 'package:memo_app/data/genre_repository.dart';
import 'package:memo_app/data/memo_repository.dart';

/// sqflite_common_ffi はテスト実行のたびに使い捨てられるインメモリDBでは
/// なく、ディスク上の実ファイルを開く。DatabaseHelper はプロセス内
/// シングルトンなので、同じテストプロセス内(同一ファイル内の複数
/// test()、あるいは以前のテスト実行の残骸)で行が積み重なってしまう。
/// 各テストの頭でこれを呼び、まっさらな状態から始める。
Future<void> clearMemoDatabase() async {
  final memoRepository = MemoRepository();
  final genreRepository = GenreRepository();

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
