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
}
