import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memo_app/providers/app_settings_provider.dart';
import 'package:memo_app/screens/theme_selection_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Locked premium theme shows a snackbar and does not select', (tester) async {
    final settings = AppSettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettingsProvider>.value(
        value: settings,
        child: const MaterialApp(home: ThemeSelectionScreen()),
      ),
    );

    expect(find.text('ホワイト(標準)'), findsOneWidget);
    expect(find.text('サクラ'), findsOneWidget);

    await tester.tap(find.text('サクラ'));
    await tester.pump();

    expect(find.text('このテーマはテーマパック購入後に使用できます'), findsOneWidget);
    expect(settings.currentTheme.id, 'white');
  });
}
