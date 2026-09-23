import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/transcription_service.dart';
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
        '思いついたことをすぐ声で録音。写真や動画も一緒に添付できます。'
        'オフラインの文字起こしでテキスト化し、'
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

/// 最後のページ(オフライン文字起こしモデルのダウンロード)を含めた
/// 総ページ数。最後の1枚だけは、他のページと違って中に操作(ダウンロード
/// ボタン)を持つため、[_kPages] とは別に組み込む。
int get _totalPages => _kPages.length + 1;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _transcriptionService = TranscriptionService();
  int _currentPage = 0;

  bool _isModelReady = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _checkModelReady();
  }

  Future<void> _checkModelReady() async {
    try {
      final ready = await _transcriptionService.isModelReady();
      if (mounted) setState(() => _isModelReady = ready);
    } catch (_) {
      // 確認できなくても支障はない(ダウンロードボタンが表示されるだけ)。
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadError = null;
    });
    try {
      await _transcriptionService.ensureModelReady(
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() => _isModelReady = true);
    } catch (e) {
      if (mounted) setState(() => _downloadError = '$e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _finish() async {
    await SettingsService().setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _next() {
    if (_currentPage == _totalPages - 1) {
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
    _transcriptionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _totalPages - 1;

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
                itemCount: _totalPages,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  if (index == _kPages.length) {
                    return _buildTranscriptionDownloadPage(context);
                  }
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
                for (var i = 0; i < _totalPages; i++)
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

  Widget _buildTranscriptionDownloadPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 96,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'オフライン文字起こしの準備',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            '音声メモを文字にするための、日本語の音声認識モデル(約50MB)を'
            '今ダウンロードしておくことができます。あとからメモ編集画面で'
            'ダウンロードすることもできるので、今はスキップしても構いません。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'ダウンロードするとオフラインで文字起こしが可能です。ただ、'
              '精度はあまり良くありません。補助的にご利用ください。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          if (_isModelReady)
            const Chip(
              avatar: Icon(Icons.check_circle, color: Colors.green),
              label: Text('ダウンロード済みです'),
            )
          else if (_isDownloading)
            Column(
              children: [
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text('${(_downloadProgress * 100).toStringAsFixed(0)}%'),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _downloadModel,
              icon: const Icon(Icons.download_outlined),
              label: const Text('今すぐダウンロード'),
            ),
          if (_downloadError != null) ...[
            const SizedBox(height: 8),
            Text(
              'ダウンロードに失敗しました: $_downloadError',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
