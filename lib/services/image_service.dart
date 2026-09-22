import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
