import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// メモに添付する画像・動画の取り込み・保存先管理を担うサービス。
///
/// 画像ピッカー/カメラが返すファイルは一時領域(キャッシュ等)にあり、
/// OS やアプリの都合でいつ消えてもおかしくない。録音ファイルと同様、
/// アプリの documents 配下にコピーしてから使う。
class ImageService {
  ImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final _uuid = const Uuid();

  Future<List<XFile>> pickFromGallery() => _picker.pickMultiImage();

  Future<XFile?> pickFromCamera() =>
      _picker.pickImage(source: ImageSource.camera);

  Future<XFile?> pickVideoFromGallery() =>
      _picker.pickVideo(source: ImageSource.gallery);

  Future<XFile?> pickVideoFromCamera() =>
      _picker.pickVideo(source: ImageSource.camera);

  /// ピッカー/カメラが返した一時ファイルをアプリの保存領域にコピーし、
  /// 新しい保存先のパスを返す。画像・動画どちらでも使える。
  Future<String> importImage(XFile source) async {
    final dir = await _imagesDirectory();
    final ext = p.extension(source.path);
    final fileName = '${_uuid.v4()}$ext';
    final destPath = p.join(dir.path, fileName);
    await File(source.path).copy(destPath);
    return destPath;
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    // 動画ならサムネイルも一緒に消す(写真の場合は最初から存在しないので
    // 単なる no-op)。
    final thumb = File(_thumbnailPathFor(path));
    if (await thumb.exists()) {
      await thumb.delete();
    }
  }

  /// 動画のサムネイル画像を生成し、そのファイルパスを返す。既に生成済みなら
  /// 再生成せずそのパスをそのまま返す(呼び出し側で毎回 [FutureBuilder] の
  /// future として渡しても、初回以降はファイルの存在確認だけで済む)。
  ///
  /// 生成に失敗した場合(壊れた動画・対応していないコーデックなど)は
  /// null を返す。呼び出し側は再生アイコンだけのプレースホルダーに
  /// フォールバックすること。
  Future<String?> ensureVideoThumbnail(String videoPath) async {
    final thumbPath = _thumbnailPathFor(videoPath);
    if (await File(thumbPath).exists()) return thumbPath;
    try {
      return await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        quality: 60,
      );
    } catch (_) {
      return null;
    }
  }

  /// 動画ファイルと同じディレクトリに、拡張子だけ変えた決まったパスを
  /// 返す(DBにサムネイル用の列を増やさずに済むようにするため)。
  String _thumbnailPathFor(String videoPath) {
    final dir = p.dirname(videoPath);
    final name = p.basenameWithoutExtension(videoPath);
    return p.join(dir, '$name.thumb.jpg');
  }

  Future<Directory> _imagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'memo_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
