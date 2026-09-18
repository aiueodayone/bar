import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_app/data/memo_repository.dart';
import 'package:memo_app/models/memo.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('soft-deleted memos are hidden from fetchMemos, listed in '
      'fetchTrashedMemos, and reappear after restoreMemo', () async {
    final repository = MemoRepository();
    final now = DateTime.now();
    final memo = Memo(
      id: 'trash-1',
      title: 'ゴミ箱テスト',
      content: '内容',
      createdAt: now,
      updatedAt: now,
    );
    await repository.upsertMemo(memo);

    expect(
      (await repository.fetchMemos()).map((m) => m.id),
      contains('trash-1'),
    );
    expect(await repository.fetchTrashedMemos(), isEmpty);

    await repository.softDeleteMemos(['trash-1']);

    expect(
      (await repository.fetchMemos()).map((m) => m.id),
      isNot(contains('trash-1')),
    );
    final trashed = await repository.fetchTrashedMemos();
    expect(trashed.map((m) => m.id), contains('trash-1'));
    expect(trashed.first.isDeleted, isTrue);

    // 期限切れ判定: 削除時刻より後のカットオフでは対象になり、
    // 削除時刻より前のカットオフでは対象にならない。
    final expiredIfCutoffInFuture = await repository.fetchExpiredTrash(
      DateTime.now().add(const Duration(days: 1)),
    );
    expect(expiredIfCutoffInFuture.map((m) => m.id), contains('trash-1'));

    final notExpiredIfCutoffInPast = await repository.fetchExpiredTrash(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      notExpiredIfCutoffInPast.map((m) => m.id),
      isNot(contains('trash-1')),
    );

    await repository.restoreMemo('trash-1');

    expect(
      (await repository.fetchMemos()).map((m) => m.id),
      contains('trash-1'),
    );
    expect(
      (await repository.fetchTrashedMemos()).map((m) => m.id),
      isNot(contains('trash-1')),
    );

    await repository.deleteMemo('trash-1');
  });
}
