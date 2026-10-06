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

      // mic は leading の丸アイコン(音声メモの従来表示)と、今回追加した
      // 添付種別アイコン行の両方に出るので2つ。photo/video は新しい
      // アイコン行にしか無いので1つずつ。
      expect(find.byIcon(Icons.mic), findsNWidgets(2));
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    },
  );
}
