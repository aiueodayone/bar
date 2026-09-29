import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_app/data/database_helper.dart';
import 'package:memo_app/data/memo_repository.dart';
import 'package:memo_app/models/memo.dart';

import 'support/db_test_utils.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // このテストファイル専用の DB ファイル(他のテストファイルと共有すると
  // 並行実行で SQLITE_BUSY になりうるため。db_test_utils.dart 参照)。
  final dbHelper = DatabaseHelper.forTesting('test_memo_favorite.db');

  setUp(() => clearMemoDatabase(dbHelper));

  test('setFavorite toggles is_favorite, and fetchMemos(favoritesOnly: true) '
      'returns only favorited memos', () async {
    final repository = MemoRepository(dbHelper: dbHelper);
    final now = DateTime.now();

    final memoA = Memo(
      id: 'fav-a',
      title: 'A',
      content: '',
      createdAt: now,
      updatedAt: now,
    );
    final memoB = Memo(
      id: 'fav-b',
      title: 'B',
      content: '',
      createdAt: now,
      updatedAt: now,
    );
    await repository.upsertMemo(memoA);
    await repository.upsertMemo(memoB);

    // デフォルトはお気に入りでない。
    final beforeAny = await repository.fetchMemoById('fav-a');
    expect(beforeAny!.isFavorite, isFalse);
    expect(await repository.fetchMemos(favoritesOnly: true), isEmpty);

    await repository.setFavorite('fav-a', true);

    final afterFavorite = await repository.fetchMemoById('fav-a');
    expect(afterFavorite!.isFavorite, isTrue);

    final favoritesOnly = await repository.fetchMemos(favoritesOnly: true);
    expect(favoritesOnly.map((m) => m.id), ['fav-a']);

    // 他の列(タイトルなど)には影響しない。
    expect(afterFavorite.title, 'A');

    await repository.setFavorite('fav-a', false);
    final afterUnfavorite = await repository.fetchMemoById('fav-a');
    expect(afterUnfavorite!.isFavorite, isFalse);
  });

  test('fetchMemos() (favoritesOnly: false) sorts favorited memos to the top '
      'regardless of updated_at', () async {
    final repository = MemoRepository(dbHelper: dbHelper);
    final older = DateTime.now().subtract(const Duration(days: 1));
    final newer = DateTime.now();

    await repository.upsertMemo(
      Memo(
        id: 'sort-old-favorite',
        title: '古いお気に入り',
        content: '',
        createdAt: older,
        updatedAt: older,
      ),
    );
    await repository.upsertMemo(
      Memo(
        id: 'sort-new-normal',
        title: '新しい普通のメモ',
        content: '',
        createdAt: newer,
        updatedAt: newer,
      ),
    );
    await repository.setFavorite('sort-old-favorite', true);

    final memos = await repository.fetchMemos();
    expect(memos.map((m) => m.id).toList(), [
      'sort-old-favorite',
      'sort-new-normal',
    ]);
  });
}
