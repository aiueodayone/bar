import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import 'home_screen.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const List<_OnboardingPage> _kPages = [
  _OnboardingPage(
    icon: Icons.lock_outline,
    title: '録音もメモも、\nすべてあなたの端末の中だけ',
    description:
        '音声メモの録音も、文字起こし(オフラインAI)も端末内で完結。'
        'あなたの声やメモの内容が外部に送信されたり、'
        'AIの学習に使われたりすることはありません。',
  ),
  _OnboardingPage(
    icon: Icons.block_outlined,
    title: 'しつこい広告に\n邪魔されない',
    description:
        '広告は控えめなバナーのみ。全画面広告や広告待ちは一切ありません。'
        '買い切り購入でいつでも完全に広告を消せます。',
  ),
  _OnboardingPage(
    icon: Icons.subtitles_outlined,
    title: '声で残して、\n文字にして整理',
    description:
        '思いついたことをすぐ声で録音。オフラインの文字起こしでテキスト化し、'
        'ジャンル分けと検索で後から迷わず見つけられます。',
  ),
  _OnboardingPage(
    icon: Icons.ios_share_outlined,
    title: '録音も文字起こしも\nメールなどですぐ共有',
    description:
        '作成した音声メモや文字起こし結果は、メールやチャットアプリなど'
        'お使いのアプリからそのまま送信できます。',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  Future<void> _finish() async {
    await SettingsService().setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _next() {
    if (_currentPage == _kPages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _kPages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(onPressed: _finish, child: const Text('スキップ')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _kPages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _kPages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _kPages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(isLastPage ? 'はじめる' : '次へ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
