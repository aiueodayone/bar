import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_app/data/database_helper.dart';
import 'package:memo_app/data/memo_image_repository.dart';
import 'package:memo_app/data/memo_repository.dart';
import 'package:memo_app/models/memo.dart';
import 'package:memo_app/models/memo_image.dart';

import 'support/db_test_utils.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // このテストファイル専用の DB ファイル(db_test_utils.dart 参照)。
  final dbHelper = DatabaseHelper.forTesting('test_memo_image.db');

  setUp(() => clearMemoDatabase(dbHelper));

  test(
    'images for a memo are returned ordered by sortOrder, and deleteImage '
    'removes just that one row',
    () async {
      final memoRepository = MemoRepository(dbHelper: dbHelper);
      final imageRepository = MemoImageRepository(dbHelper: dbHelper);
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
      final memoRepository = MemoRepository(dbHelper: dbHelper);
      final imageRepository = MemoImageRepository(dbHelper: dbHelper);
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

  test(
    'attachment type (image vs video) round-trips through insert/fetch, and '
    'defaults to image when not given',
    () async {
      final memoRepository = MemoRepository(dbHelper: dbHelper);
      final imageRepository = MemoImageRepository(dbHelper: dbHelper);
      final now = DateTime.now();

      await memoRepository.upsertMemo(
        Memo(
          id: 'img-memo-3',
          title: 'タイプテスト',
          content: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await imageRepository.insertImage(
        MemoImage(
          id: 'img-4',
          memoId: 'img-memo-3',
          path: '/tmp/four.jpg',
          sortOrder: 0,
          createdAt: now,
        ),
      );
      await imageRepository.insertImage(
        MemoImage(
          id: 'img-5',
          memoId: 'img-memo-3',
          path: '/tmp/five.mp4',
          sortOrder: 1,
          createdAt: now,
          type: MemoAttachmentType.video,
        ),
      );

      final images = await imageRepository.fetchImagesForMemo('img-memo-3');
      expect(images[0].type, MemoAttachmentType.image);
      expect(images[0].isVideo, isFalse);
      expect(images[1].type, MemoAttachmentType.video);
      expect(images[1].isVideo, isTrue);
    },
  );

  test(
    're-saving an existing memo (as the edit screen does before opening the '
    'camera/gallery for each attachment, and again on final save) must not '
    'wipe its already-attached images/videos',
    () async {
      final memoRepository = MemoRepository(dbHelper: dbHelper);
      final imageRepository = MemoImageRepository(dbHelper: dbHelper);
      final now = DateTime.now();

      final memo = Memo(
        id: 'img-memo-4',
        title: '',
        content: '',
        createdAt: now,
        updatedAt: now,
      );
      await memoRepository.upsertMemo(memo);

      // 1枚目(写真)を撮った直後、すぐDBに追加(eager insert)。
      await imageRepository.insertImage(
        MemoImage(
          id: 'img-6',
          memoId: 'img-memo-4',
          path: '/tmp/six.jpg',
          sortOrder: 0,
          createdAt: now,
        ),
      );

      // 2つ目(動画)を追加しようとカメラ/ギャラリーを開く前に、
      // 編集画面は毎回 _autosaveBeforeLeavingApp() でメモ行を再保存する。
      // これが memo_images の行を巻き込んで消してしまわないこと。
      await memoRepository.upsertMemo(memo.copyWith(title: '下書き'));

      expect(
        (await imageRepository.fetchImagesForMemo('img-memo-4'))
            .map((i) => i.id),
        ['img-6'],
      );

      // 2枚目(動画)が追加された後、insertImage 直後。
      await imageRepository.insertImage(
        MemoImage(
          id: 'img-7',
          memoId: 'img-memo-4',
          path: '/tmp/seven.mp4',
          sortOrder: 1,
          createdAt: now,
          type: MemoAttachmentType.video,
        ),
      );

      // 最終保存(_save() 側)でもう一度 upsertMemo が呼ばれる。
      await memoRepository.upsertMemo(memo.copyWith(title: '完成版'));

      final finalImages = await imageRepository.fetchImagesForMemo(
        'img-memo-4',
      );
      expect(finalImages.map((i) => i.id).toList(), ['img-6', 'img-7']);
    },
  );
}
