/// メモに添付された画像1枚を表すモデル。1件のメモに複数枚添付できる。
class MemoImage {
  MemoImage({
    required this.id,
    required this.memoId,
    required this.path,
    required this.sortOrder,
    required this.createdAt,
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
    );
  }

  final String id;
  final String memoId;
  final String path;
  final int sortOrder;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'memo_id': memoId,
      'path': path,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
