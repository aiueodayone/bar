import 'package:audioplayers/audioplayers.dart';

/// 録音した音声メモの再生を扱うサービス。
class PlaybackService {
  PlaybackService() : _player = AudioPlayer();

  final AudioPlayer _player;

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.resume();

  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  void dispose() {
    _player.dispose();
  }
}
