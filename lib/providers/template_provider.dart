import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/template_repository.dart';
import '../models/meeting_template.dart';

/// 議事録テンプレート(プリセット + カスタム)の状態を管理する。
class TemplateProvider extends ChangeNotifier {
  TemplateProvider({TemplateRepository? repository})
      : _repository = repository ?? TemplateRepository();

  final TemplateRepository _repository;
  final _uuid = const Uuid();

  List<MeetingTemplate> _customTemplates = [];

  /// プリセット + カスタムテンプレートをまとめた一覧。
  List<MeetingTemplate> get templates => [
        ...kBuiltInTemplates,
        ..._customTemplates,
      ];

  List<MeetingTemplate> get customTemplates =>
      List.unmodifiable(_customTemplates);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _customTemplates = await _repository.fetchCustomTemplates();
    _isLoading = false;
    notifyListeners();
  }

  Future<MeetingTemplate> addTemplate(String name, String body) async {
    final template = MeetingTemplate(id: _uuid.v4(), name: name, body: body);
    await _repository.upsertTemplate(template);
    await load();
    return template;
  }

  Future<void> updateTemplate(
    MeetingTemplate template,
    String name,
    String body,
  ) async {
    if (template.isBuiltIn) return;
    await _repository.upsertTemplate(
      MeetingTemplate(id: template.id, name: name, body: body),
    );
    await load();
  }

  Future<void> deleteTemplate(MeetingTemplate template) async {
    if (template.isBuiltIn) return;
    await _repository.deleteTemplate(template.id);
    await load();
  }
}
