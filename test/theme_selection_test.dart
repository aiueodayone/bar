import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memo_app/models/app_theme.dart';
import 'package:memo_app/providers/app_settings_provider.dart';
import 'package:memo_app/screens/theme_selection_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Selecting a free theme applies it immediately', (tester) async {
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

    expect(settings.currentTheme.id, 'sakura');
  });

  test('selectTheme ignores a premium theme until themesUnlocked, '
      'even though no current theme is premium', () async {
    // kAppThemes は現在すべて無料だが、将来premiumテーマを追加した際に
    // 備えて、ロック機構そのものはここで直接 AppTheme を組み立てて検証する。
    const premiumTheme = AppTheme(
      id: 'future_premium',
      name: '将来の有料テーマ',
      seedColor: Colors.purple,
      isPremium: true,
    );
    final settings = AppSettingsProvider();

    await settings.selectTheme(premiumTheme);
    expect(settings.currentTheme.id, isNot('future_premium'));
  });
}
