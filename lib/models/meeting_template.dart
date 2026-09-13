/// 議事録などを作成する際の雛形(テンプレート)。
class MeetingTemplate {
  const MeetingTemplate({
    required this.id,
    required this.name,
    required this.body,
    this.isBuiltIn = false,
  });

  factory MeetingTemplate.fromMap(Map<String, Object?> map) {
    return MeetingTemplate(
      id: map['id']! as String,
      name: map['name']! as String,
      body: map['body']! as String,
    );
  }

  final String id;
  final String name;
  final String body;

  /// true の場合はアプリ同梱のプリセットで、編集・削除はできない。
  final bool isBuiltIn;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'body': body,
    };
  }
}

/// アプリに同梱されている議事録テンプレートのプリセット。
final List<MeetingTemplate> kBuiltInTemplates = [
  MeetingTemplate(
    id: 'builtin_standard',
    name: '標準議事録',
    isBuiltIn: true,
    body: '''【会議名】
【日時】
【場所】
【参加者】

【議題】


【決定事項】


【ToDo(担当・期限)】


【次回予定】
''',
  ),
  MeetingTemplate(
    id: 'builtin_regular',
    name: '定例ミーティング',
    isBuiltIn: true,
    body: '''【日時】
【参加者】

【前回のアクションの確認】


【共有事項】


【今回の決定事項】


【次回までのアクション(担当・期限)】
''',
  ),
  MeetingTemplate(
    id: 'builtin_1on1',
    name: '1on1',
    isBuiltIn: true,
    body: '''【日時】
【相手】

【最近の状況】


【トピック】


【フィードバック】


【次のアクション】
''',
  ),
  MeetingTemplate(
    id: 'builtin_brainstorm',
    name: 'ブレインストーミング',
    isBuiltIn: true,
    body: '''【テーマ】
【参加者】

【出たアイデア】
・
・
・

【次のアクション】
''',
  ),
];
