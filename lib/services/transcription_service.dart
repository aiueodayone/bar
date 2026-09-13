/// オフライン音声認識(Vosk)を利用した文字起こしを提供するサービス。
///
/// 診断用ビルド: vosk_flutter が原因と疑われるネイティブクラッシュを
/// 切り分けるため、一時的に実処理を無効化している。
/// (公開APIの形は維持し、呼び出し側 [memo_edit_screen.dart] の変更を避ける)
class TranscriptionService {
  Future<void> ensureModelReady({
    void Function(double progress)? onProgress,
  }) async {
    throw StateError('この診断用ビルドでは文字起こし機能を一時的に無効化しています');
  }

  Future<bool> isModelReady() async => false;

  Future<String> transcribeWavFile(String wavPath) async {
    throw StateError('この診断用ビルドでは文字起こし機能を一時的に無効化しています');
  }

  void dispose() {}
}
