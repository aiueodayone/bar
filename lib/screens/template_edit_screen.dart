import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meeting_template.dart';
import '../providers/template_provider.dart';

/// カスタムテンプレートの新規作成・編集画面。
class TemplateEditScreen extends StatefulWidget {
  const TemplateEditScreen({super.key, this.template, this.duplicateFrom});

  /// 編集対象の既存カスタムテンプレート(新規作成時は null)。
  final MeetingTemplate? template;

  /// プリセットなどを「コピーして編集」する際の複製元。
  final MeetingTemplate? duplicateFrom;

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late final _nameController = TextEditingController(
    text: widget.template?.name ?? widget.duplicateFrom?.name ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.template?.body ?? widget.duplicateFrom?.body ?? '',
  );

  bool get _isEditing => widget.template != null;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final body = _bodyController.text;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレート名を入力してください')),
      );
      return;
    }

    final provider = context.read<TemplateProvider>();
    if (_isEditing) {
      await provider.updateTemplate(widget.template!, name, body);
    } else {
      await provider.addTemplate(name, body);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'テンプレートを編集' : '新しいテンプレート'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'テンプレート名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(
              labelText: '本文の雛形',
              helperText: '新規メモ作成時にここで書いた内容がそのまま本文に入ります',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 16,
            minLines: 10,
          ),
        ],
      ),
    );
  }
}
