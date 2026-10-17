import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:memo_app/main.dart';
import 'package:memo_app/services/settings_service.dart';
import 'package:memo_app/widgets/memo_list_item.dart';

/// 実機/エミュレータ上で動かす結合テスト。CI では複数の Android API
/// レベルのエミュレータ上でこれを実行し、手もとに無い端末での動作を
/// 確認する(.github/workflows/build-apk.yml の integration_test ジョブ)。
///
/// ここでは `main()` を直接呼ばず [MemoApp] を pump する。main() は広告SDK
/// の初期化(ネットワーク呼び出しを伴う)を裏で走らせる作りになっており、
/// それをテストの不安定要因にしたくないため。広告はテスト開始前に
/// 「解除済み」にしておき、そもそも読み込ませない。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('起動 → オンボーディングのスキップ → テキストメモの作成・お気に入り登録・削除', (tester) async {
    await SettingsService().setAdsRemoved(true);

    await tester.pumpWidget(const MemoApp());
    await tester.pumpAndSettle();

    // 初回起動はオンボーディングが挟まるので、スキップしてホームへ進む。
    final skipButton = find.text('スキップ');
    if (skipButton.evaluate().isNotEmpty) {
      await tester.tap(skipButton);
      await tester.pumpAndSettle();
    }

    expect(find.text('手もとメモ'), findsOneWidget);
    expect(find.textContaining('メモがありません'), findsOneWidget);

    // 新規メモを作成する。
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    const title = '結合テストメモ';
    const content = 'Androidエミュレータ上で自動作成したメモです。';
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.first, title);
    await tester.enterText(textFields.at(1), content);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // ホームに戻り、作成したメモが一覧に出ていることを確認する。
    expect(find.text(title), findsOneWidget);

    // お気に入りに登録する(AppBar側の絞り込みアイコンと紛れないよう、
    // MemoListItem の中だけを探す)。
    final favoriteIcon = find.descendant(
      of: find.byType(MemoListItem),
      matching: find.byIcon(Icons.star_border),
    );
    expect(favoriteIcon, findsOneWidget);
    await tester.tap(favoriteIcon);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(MemoListItem),
        matching: find.byIcon(Icons.star),
      ),
      findsOneWidget,
    );

    // 一覧からの複数選択削除(長押し)は、一覧アイテム内の他のタップ領域
    // (お気に入りボタンなど)とのジェスチャー競合でCI上の仮想端末だと
    // 不安定だったため、より単純で確実な経路(編集画面を開いて削除)を使う。
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('メモを編集'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.text(title), findsNothing);
    expect(find.textContaining('メモがありません'), findsOneWidget);
  });
}
