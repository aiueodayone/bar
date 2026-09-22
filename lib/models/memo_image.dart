/// メモに添付するメディアの種類。
enum MemoAttachmentType {
  image,
  video;

  static MemoAttachmentType fromName(String name) {
    return MemoAttachmentType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => MemoAttachmentType.image,
    );
  }
}

/// メモに添付された画像・動画1件を表すモデル。1件のメモに複数添付できる。
///
/// テーブル名・クラス名は memo_images / MemoImage のままだが、[type] が
/// 動画対応の追加(DB version 4)以降は画像・動画の両方を指す。
class MemoImage {
  MemoImage({
    required this.id,
    required this.memoId,
    required this.path,
    required this.sortOrder,
    required this.createdAt,
    this.type = MemoAttachmentType.image,
  });

  factory MemoImage.fromMap(Map<String, Object?> map) {
    return MemoImage(
      id: map['id']! as String,
      memoId: map['memo_id']! as String,
      path: map['path']! as String,
      sortOrder: map['sort_order']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at']! as int,
      ),
      type: MemoAttachmentType.fromName(map['type'] as String? ?? 'image'),
    );
  }

  final String id;
  final String memoId;
  final String path;
  final int sortOrder;
  final DateTime createdAt;
  final MemoAttachmentType type;

  bool get isVideo => type == MemoAttachmentType.video;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'memo_id': memoId,
      'path': path,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'type': type.name,
    };
  }
}
