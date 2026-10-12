import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memo_app/models/genre.dart';
import 'package:memo_app/models/memo.dart';
import 'package:memo_app/widgets/memo_list_item.dart';

void main() {
  testWidgets('MemoListItem shows title and genre name', (tester) async {
    final now = DateTime(2026, 1, 1, 9, 30);
    final memo = Memo(
      id: 'm1',
      title: '買い物リスト',
      content: '牛乳、卵、パン',
      createdAt: now,
      updatedAt: now,
      genreId: 'g1',
    );
    final genre = Genre(id: 'g1', name: '生活', color: Colors.teal);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoListItem(
            memo: memo,
            genre: genre,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(find.text('買い物リスト'), findsOneWidget);
    expect(find.text('生活'), findsOneWidget);
  });

  testWidgets('MemoListItem: a memo with no attachments shows no type icons', (
    tester,
  ) async {
    final now = DateTime(2026, 1, 1, 9, 30);
    final memo = Memo(
      id: 'm-plain',
      title: 'プレーン',
      content: '',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoListItem(
            memo: memo,
            genre: null,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.photo_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
  });

  testWidgets(
    'MemoListItem: a memo with audio+photo+video shows all three icons',
    (tester) async {
      final now = DateTime(2026, 1, 1, 9, 30);
      final memo = Memo(
        id: 'm-all',
        title: '音声+写真+動画',
        content: '',
        audioPath: '/tmp/audio.m4a',
        createdAt: now,
        updatedAt: now,
        hasImage: true,
        hasVideo: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoListItem(
              memo: memo,
              genre: null,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      // leading の丸アイコンは音声・写真・動画が全部揃っているときは
      // 優先順位(動画 > 写真 > 音声)により videocam になり、trailing の
      // 添付種別アイコン行には mic/photo_outlined/videocam_outlined が
      // それぞれ1つずつ出る。
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      // leading の丸アイコン本体(動画が最優先)。
      expect(find.byIcon(Icons.videocam), findsOneWidget);
    },
  );

  testWidgets(
    'MemoListItem: leading icon reflects attachment type when there is no '
    'audio (photo-only memo shows a photo icon, not the plain notes icon)',
    (tester) async {
      final now = DateTime(2026, 1, 1, 9, 30);
      final memo = Memo(
        id: 'm-photo-only',
        title: '写真のみ',
        content: '',
        createdAt: now,
        updatedAt: now,
        hasImage: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemoListItem(
              memo: memo,
              genre: null,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.photo), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsNothing);
    },
  );
}
