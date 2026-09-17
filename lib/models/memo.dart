/// 1件のメモ(テキスト or 音声メモ)を表すモデル。
class Memo {
  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.genreId,
    this.audioPath,
    this.audioDurationMs,
  });

  factory Memo.fromMap(Map<String, Object?> map) {
    return Memo(
      id: map['id']! as String,
      title: map['title']! as String,
      content: map['content']! as String,
      genreId: map['genre_id'] as String?,
      audioPath: map['audio_path'] as String?,
      audioDurationMs: map['audio_duration_ms'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    );
  }

  final String id;
  final String title;
  final String content;
  final String? genreId;
  final String? audioPath;
  final int? audioDurationMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'genre_id': genreId,
      'audio_path': audioPath,
      'audio_duration_ms': audioDurationMs,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  Memo copyWith({
    String? title,
    String? content,
    String? genreId,
    bool clearGenre = false,
    String? audioPath,
    int? audioDurationMs,
    bool clearAudio = false,
    DateTime? updatedAt,
  }) {
    return Memo(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      genreId: clearGenre ? null : (genreId ?? this.genreId),
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      audioDurationMs: clearAudio
          ? null
          : (audioDurationMs ?? this.audioDurationMs),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
