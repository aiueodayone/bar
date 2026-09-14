import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'providers/app_settings_provider.dart';
import 'providers/genre_provider.dart';
import 'providers/memo_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/settings_service.dart';

void main() {
  // 想定していない箇所で例外が出ても、アプリ全体が落ちるのではなく
  // ログに残すだけに留める安全網。個別の対処(広告SDK・課金APIなど)は
  // それぞれの箇所でも別途 try/catch している。
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };

      try {
        await MobileAds.instance.initialize();
      } catch (_) {
        // 広告なしで続行
      }

      runApp(const MemoApp());
    },
    (error, stack) {
      // 未捕捉の例外はここで握りつぶし、アプリを落とさない。
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MemoProvider()..load()),
        ChangeNotifierProvider(create: (_) => GenreProvider()..load()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..init()),
      ],
      child: Builder(
        builder: (context) {
          final seedColor =
              context.watch<AppSettingsProvider>().currentTheme.seedColor;
          return MaterialApp(
            title: '手もとメモ',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ja', 'JP'),
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
              scaffoldBackgroundColor: Colors.white,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            home: const _AppEntryPoint(),
          );
        },
      ),
    );
  }
}

/// 初回起動かどうかを判定し、オンボーディングかホーム画面のどちらかを表示する。
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  late final Future<bool> _hasSeenOnboarding =
      SettingsService().hasSeenOnboarding();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSeenOnboarding,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
      },
    );
  }
}
