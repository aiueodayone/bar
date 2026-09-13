import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memo_app/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OnboardingScreen paginates through all pages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );

    expect(find.text('録音もメモも、\nすべてあなたの端末の中だけ'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);
    expect(find.text('スキップ'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }

    expect(find.text('議事録もテンプレートで\nすぐ書ける'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);
  });
}
