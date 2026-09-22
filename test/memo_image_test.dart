import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_app/data/memo_image_repository.dart';
import 'package:memo_app/data/memo_repository.dart';
import 'package:memo_app/models/memo.dart';
import 'package:memo_app/models/memo_image.dart';

import 'support/db_test_utils.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(clearMemoDatabase);

  test(
    'images for a memo are returned ordered by sortOrder, and deleteImage '
    'removes just that one row',
    () async {
      final memoRepository = MemoRepository();
      final imageRepository = MemoImageRepository();
      final now = DateTime.now();

      await memoRepository.upsertMemo(
        Memo(
          id: 'img-memo-1',
          title: '画像テスト',
          content: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await imageRepository.insertImage(
        MemoImage(
          id: 'img-2',
          memoId: 'img-memo-1',
          path: '/tmp/two.jpg',
          sortOrder: 1,
          createdAt: now,
        ),
      );
      await imageRepository.insertImage(
        MemoImage(
          id: 'img-1',
          memoId: 'img-memo-1',
          path: '/tmp/one.jpg',
          sortOrder: 0,
          createdAt: now,
        ),
      );

      final images = await imageRepository.fetchImagesForMemo('img-memo-1');
      expect(images.map((i) => i.id).toList(), ['img-1', 'img-2']);

      await imageRepository.deleteImage('img-1');
      final afterDelete = await imageRepository.fetchImagesForMemo(
        'img-memo-1',
      );
      expect(afterDelete.map((i) => i.id).toList(), ['img-2']);
    },
  );

  test(
    'deleting the memo row cascades to delete its memo_images rows too',
    () async {
      final memoRepository = MemoRepository();
      final imageRepository = MemoImageRepository();
      final now = DateTime.now();

      await memoRepository.upsertMemo(
        Memo(
          id: 'img-memo-2',
          title: 'カスケード削除テスト',
          content: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await imageRepository.insertImage(
        MemoImage(
          id: 'img-3',
          memoId: 'img-memo-2',
          path: '/tmp/three.jpg',
          sortOrder: 0,
          createdAt: now,
        ),
      );

      expect(
        await imageRepository.fetchImagesForMemo('img-memo-2'),
        isNotEmpty,
      );

      // deleteImage を呼ばず、メモの行そのものを消すだけで
      // memo_images 側の行も外部キーの ON DELETE CASCADE で消えるはず。
      await memoRepository.deleteMemo('img-memo-2');

      expect(await imageRepository.fetchImagesForMemo('img-memo-2'), isEmpty);
    },
  );
}
