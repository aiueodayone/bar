import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'providers/app_lock_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/genre_provider.dart';
import 'providers/memo_provider.dart';
import 'screens/app_lock_screen.dart';
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

      _registerAdditionalLicenses();

      // 広告SDKの初期化はネットワーク状況によっては数秒〜それ以上かかる
      // ことがある。ここで await してしまうと、その間ずっとアプリの最初の
      // 画面が描画されず(OS側のスプラッシュがぐるぐる回り続けたように
      // 見える)、起動が遅くなる。BannerAdWidget 側は読み込み前は何も
      // 表示しない作りになっているので、待たずに裏で初期化を進める。
      unawaited(_initAds());

      runApp(const MemoApp());
    },
    (error, stack) {
      // 未捕捉の例外はここで握りつぶし、アプリを落とさない。
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

Future<void> _initAds() async {
  try {
    await MobileAds.instance.initialize();
  } catch (_) {
    // 広告なしで続行
  }
}

/// 「設定」→「ライセンスを表示」ページは pub パッケージに同梱された
/// LICENSE ファイルを自動収集するだけで、初回文字起こし時に実行時
/// ダウンロードする日本語音声認識モデル(vosk-model-small-ja-0.22、
/// alphacephei.com配布)はアプリに同梱されていないため自動収集の対象に
/// ならない。同じ Apache License 2.0 のモデルであることをここで明示的に
/// 登録し、ライセンス一覧にも表示されるようにする。
void _registerAdditionalLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['vosk-model-small-ja-0.22'],
      '文字起こし機能は、初回利用時に日本語音声認識モデル '
      '(vosk-model-small-ja-0.22) を https://alphacephei.com/vosk/models '
      'からダウンロードして使用します。このモデルは Vosk 本体と同じく '
      'Apache License 2.0 のもとで配布されています。\n\n'
      '$_apacheLicense20',
    );
  });
}

const _apacheLicense20 = '''
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the
      purposes of this License, Derivative Works shall not include works
      that remain separable from, or merely link (or bind by name) to the
      interfaces of, the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including the
      original version of the Work and any modifications or additions to
      that Work or Derivative Works thereof, that is intentionally submitted
      to Licensor for inclusion in the Work by the copyright owner or by an
      individual or Legal Entity authorized to submit on behalf of the
      copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control
      systems, and issue tracking systems that are managed by, or on behalf
      of, the Licensor for the purpose of discussing and improving the
      Work, but excluding communication that is conspicuously marked or
      otherwise designated in writing by the copyright owner as
      "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the Work
      or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or Derivative
          Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and do
          not modify the License. You may add Your own attribution notices
          within Derivative Works that You distribute, alongside or as an
          addendum to the NOTICE text from the Work, provided that such
          additional attribution notices cannot be construed as modifying
          the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing
      the origin of the Work and reproducing the content of the NOTICE
      file.

   7. Disclaimer of Warranty. Unless required by applicable law or agreed
      to in writing, Licensor provides the Work (and each Contributor
      provides its Contributions) on an "AS IS" BASIS, WITHOUT WARRANTIES
      OR CONDITIONS OF ANY KIND, either express or implied, including,
      without limitation, any warranties or conditions of TITLE,
      NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A PARTICULAR
      PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this
      License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS
''';

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MemoProvider()
            ..load()
            ..purgeExpiredTrash(),
        ),
        ChangeNotifierProvider(create: (_) => GenreProvider()..load()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => AppLockProvider()..init()),
      ],
      child: Builder(
        builder: (context) {
          final appSettings = context.watch<AppSettingsProvider>();
          final seedColor = appSettings.currentTheme.seedColor;
          return MaterialApp(
            title: '手もとメモ',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ja', 'JP'),
            themeMode: appSettings.darkModeEnabled
                ? ThemeMode.dark
                : ThemeMode.light,
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
              scaffoldBackgroundColor: Colors.black,
              useMaterial3: true,
            ),
            home: const _AppLockGate(child: _AppEntryPoint()),
          );
        },
      ),
    );
  }
}

/// アプリロックが有効なときに、起動時とバックグラウンド復帰時に
/// [AppLockScreen] を割り込ませる。
class _AppLockGate extends StatefulWidget {
  const _AppLockGate({required this.child});

  final Widget child;

  @override
  State<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<_AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンドに退避したタイミングで再ロックする。他人に端末を
    // 渡した/置き忘れた場合でも、次にアプリを開く際は必ずパスワードを
    // 要求するようにするため。
    if (state == AppLifecycleState.paused) {
      context.read<AppLockProvider>().lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = context.watch<AppLockProvider>().isLocked;
    return isLocked ? const AppLockScreen() : widget.child;
  }
}

/// 初回起動かどうかを判定し、オンボーディングかホーム画面のどちらかを表示する。
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  late final Future<bool> _hasSeenOnboarding = SettingsService()
      .hasSeenOnboarding();

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
