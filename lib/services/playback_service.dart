import 'package:audioplayers/audioplayers.dart';

/// 録音した音声メモの再生を扱うサービス。
class PlaybackService {
  PlaybackService() : _player = AudioPlayer();

  final AudioPlayer _player;

  // 明示的な AudioContext を指定しないと、端末や直前の録音状態によっては
  // 再生が受話口(耳に当てて聞く小さいスピーカー)側に出力され、
  // 「音声メモが聞き取れない」ほど小さい音になることがある。
  // isSpeakerphoneOn を true にして、常に本体のスピーカーへ出力する。
  static final _playbackContext = AudioContext(
    android: const AudioContextAndroid(isSpeakerphoneOn: true),
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
