import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Vosk のモデルが期待するサンプルレート。録音もこれに合わせておく。
const int kAudioSampleRate = 16000;

/// マイクからの音声メモ録音を扱うサービス。
class AudioService {
  AudioService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  DateTime? _startedAt;

  Future<bool> hasPermission() => _recorder.hasPermission();

  bool get isRecording => _startedAt != null;

  /// 録音を開始し、保存先のファイルパスを返す。
  Future<String> start() async {
    if (!await hasPermission()) {
      throw StateError('マイクの使用が許可されていません');
    }
    final dir = await _recordingsDirectory();
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    final path = p.join(dir.path, fileName);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: kAudioSampleRate,
        numChannels: 1,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
    return path;
  }

  /// 録音を停止し、(ファイルパス, 録音時間ミリ秒) を返す。
  Future<(String?, int)> stop() async {
    final path = await _recorder.stop();
    final durationMs = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    _startedAt = null;
    return (path, durationMs);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _startedAt = null;
  }

  Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  Future<Directory> _recordingsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'voice_memos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
