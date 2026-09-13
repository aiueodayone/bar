import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meeting_template.dart';
import '../providers/template_provider.dart';
import 'template_management_screen.dart';

/// 議事録メモを作るためのテンプレートを選ぶ画面。
/// 選んだテンプレートを Navigator.pop で呼び出し元に返す。
class TemplatePickerScreen extends StatelessWidget {
  const TemplatePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templateProvider = context.watch<TemplateProvider>();
    final templates = templateProvider.templates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('テンプレートを選択'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'テンプレートを管理',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TemplateManagementScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: templates.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final template = templates[index];
          final preview = template.body
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .take(3)
              .join(' / ');
          return ListTile(
            leading: Icon(
              template.isBuiltIn ? Icons.description_outlined : Icons.edit_note,
            ),
            title: Text(template.name),
            subtitle: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).pop<MeetingTemplate>(template),
          );
        },
      ),
    );
  }
}
