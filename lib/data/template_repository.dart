import 'package:sqflite/sqflite.dart';

import '../models/meeting_template.dart';
import 'database_helper.dart';

/// カスタム議事録テンプレートの永続化を担うリポジトリ。
/// (プリセットのテンプレートは DB に保存せず、アプリ内定数として保持する)
class TemplateRepository {
  TemplateRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<MeetingTemplate>> fetchCustomTemplates() async {
    final db = await _dbHelper.database;
    final rows = await db.query('templates', orderBy: 'name ASC');
    return rows.map(MeetingTemplate.fromMap).toList();
  }

  Future<void> upsertTemplate(MeetingTemplate template) async {
    final db = await _dbHelper.database;
    await db.insert(
      'templates',
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTemplate(String id) async {
    final db = await _dbHelper.database;
    await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }
}
