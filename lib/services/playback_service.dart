import 'package:audioplayers/audioplayers.dart';

/// 録音した音声メモの再生を扱うサービス。
class PlaybackService {
  PlaybackService() : _player = AudioPlayer();

  final AudioPlayer _player;

  // 明示的な AudioContext を指定しないと setAudioContext 自体が一度も
  // 呼ばれず、録音時に変わった可能性のある AudioManager の状態(mode 等)が
  // 再生時までそのまま残ってしまうことがある。isSpeakerphoneOn は
  // true にしない(それはAndroidの「スピーカーホン」機能そのもので、
  // イヤホン接続時もお構いなしに本体スピーカーへ強制してしまうため、
  // イヤホン使用時に逆に聞こえなくなる)。あくまで音楽再生用の標準的な
  // AudioAttributes(USAGE_MEDIA / CONTENT_TYPE_MUSIC)と
  // audioMode=MODE_NORMAL を明示的に適用し直すだけに留める。
  static final _playbackContext = AudioContext(
    android: const AudioContextAndroid(),
  );

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;
  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path), ctx: _playbackContext);
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.resume();

  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  void dispose() {
    _player.dispose();
  }
}
