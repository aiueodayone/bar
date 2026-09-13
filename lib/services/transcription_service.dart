import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'audio_service.dart';

/// オフライン音声認識(Vosk)を利用した文字起こしを提供するサービス。
///
/// 初回のみ日本語モデル(フルサイズ・約1GB)をダウンロードしてアプリの
/// 保存領域に展開する。以降は完全にオフラインで文字起こしが行える。
/// 軽量版(vosk-model-small-ja)より精度は高いが、ダウンロードにも文字
/// 起こし自体にも時間がかかる。
class TranscriptionService {
  static const String modelName = 'vosk-model-ja-0.22';
  static const String modelUrl =
      'https://alphacephei.com/vosk/models/$modelName.zip';

  Model? _model;

  /// モデルのダウンロード進捗(0.0〜1.0)を通知しつつダウンロード・展開する。
  /// すでにダウンロード済みの場合は何もせず即座に完了する。
  Future<void> ensureModelReady({
    void Function(double progress)? onProgress,
  }) async {
    final modelDir = await _modelDirectory();
    if (await modelDir.exists() && !(await modelDir.list().isEmpty)) {
      onProgress?.call(1);
      return;
    }

    // フルサイズモデルは約1GB。zip全体をメモリ上の List<int> に貯めてから
    // 展開すると、ダウンロード分＋展開時の一時コピー分で端末のメモリを
    // 圧迫し OOM で落ちかねないため、いったんディスクへストリーミング
    // 保存し、zip の展開もファイルから直接ストリーミングで行う。
    final zipFile = await _downloadToTempFile(modelUrl, onProgress);
    try {
      await Isolate.run(() {
        final inputStream = InputFileStream(zipFile.path);
        try {
          final archive = ZipDecoder().decodeBuffer(inputStream);
          _extractModelArchive(archive, modelDir.path);
        } finally {
          inputStream.close();
        }
      });
    } finally {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }

    // 配布元が zip 内部のトップレベルフォルダ名を変更した場合など、
    // 展開しても想定のパスにモデルが現れないことがある。ここで確定させて
    // おかないと、次に文字起こしを実行した瞬間に分かりにくいエラーになる。
    if (!await modelDir.exists() || await modelDir.list().isEmpty) {
      throw StateError('モデルの展開に失敗しました。お手数ですが、もう一度お試しください');
    }
  }

  /// zip 内のトップレベルフォルダ名がこちらの想定([modelName])と一致しなくても
  /// 文字起こしできるよう、トップレベルの1階層を読み飛ばして常に [destDir] 直下へ
  /// 展開する(Vosk のモデル配布物は通常「<モデル名>/am/...」のように
  /// 単一のルートフォルダを含む)。
  static void _extractModelArchive(Archive archive, String destDir) {
    for (final file in archive.files) {
      final parts = p.split(file.name.replaceAll('\\', '/'));
      if (parts.length <= 1) continue;
      final relativePath = p.joinAll(parts.skip(1));
      if (relativePath.isEmpty) continue;
      final outPath = p.join(destDir, relativePath);
      if (!file.isFile) {
        Directory(outPath).createSync(recursive: true);
        continue;
      }
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
    }
  }

  Future<bool> isModelReady() async {
    final modelDir = await _modelDirectory();
    return modelDir.exists();
  }

  Future<void> _loadModelIfNeeded() async {
    if (_model != null) return;
    final modelDir = await _modelDirectory();
    if (!await modelDir.exists()) {
      throw StateError('文字起こしモデルがまだダウンロードされていません');
    }
    final vosk = VoskFlutterPlugin.instance();
    _model = await vosk.createModel(modelDir.path);
  }

  /// 録音済みの WAV ファイル(16bit PCM, モノラル)からテキストを書き起こす。
  Future<String> transcribeWavFile(String wavPath) async {
    await _loadModelIfNeeded();
    final vosk = VoskFlutterPlugin.instance();
    final recognizer = await vosk.createRecognizer(
      model: _model!,
      sampleRate: kAudioSampleRate,
    );

    try {
      final bytes = await File(wavPath).readAsBytes();
      final pcm = _stripWavHeader(bytes);

      const chunkSize = 8192;
      var pos = 0;
      while (pos + chunkSize < pcm.length) {
        await recognizer.acceptWaveformBytes(
          Uint8List.sublistView(pcm, pos, pos + chunkSize),
        );
        pos += chunkSize;
      }
      if (pos < pcm.length) {
        await recognizer.acceptWaveformBytes(
          Uint8List.sublistView(pcm, pos, pcm.length),
        );
      }

      final resultJson = await recognizer.getFinalResult();
      final decoded = jsonDecode(resultJson) as Map<String, dynamic>;
      return (decoded['text'] as String?)?.trim() ?? '';
    } finally {
      await recognizer.dispose();
    }
  }

  Future<File> _downloadToTempFile(
    String url,
    void Function(double progress)? onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      var received = 0;

      final modelsRoot = await _modelsRootDirectory();
      final zipFile = File(p.join(modelsRoot.path, '$modelName.zip.part'));
      final sink = zipFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress?.call(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      return zipFile;
    } finally {
      client.close();
    }
  }

  Uint8List _stripWavHeader(Uint8List bytes) {
    // 標準的な WAV(RIFF)ファイルの 'data' サブチャンクを探して、
    // そこから先の生の PCM サンプルだけを取り出す。
    final byteData = ByteData.sublistView(bytes);
    var offset = 12; // "RIFF" + size(4) + "WAVE"
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = byteData.getUint32(offset + 4, Endian.little);
      final dataStart = offset + 8;
      if (chunkId == 'data') {
        final end = (dataStart + chunkSize) > bytes.length
            ? bytes.length
            : dataStart + chunkSize;
        return Uint8List.sublistView(bytes, dataStart, end);
      }
      offset = dataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    // data チャンクが見つからない場合は、そのまま返す(フォールバック)。
    return bytes;
  }

  Future<Directory> _modelsRootDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _modelDirectory() async {
    final root = await _modelsRootDirectory();
    return Directory(p.join(root.path, modelName));
  }

  void dispose() {
    _model?.dispose();
  }
}
