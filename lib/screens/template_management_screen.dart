import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meeting_template.dart';
import '../providers/template_provider.dart';
import 'template_edit_screen.dart';

class TemplateManagementScreen extends StatelessWidget {
  const TemplateManagementScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    MeetingTemplate template,
  ) async {
    final provider = context.read<TemplateProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートを削除しますか?'),
        content: Text('「${template.name}」を削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await provider.deleteTemplate(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('議事録テンプレート管理')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'プリセット',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final template in kBuiltInTemplates)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(template.name),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TemplateEditScreen(duplicateFrom: template),
                  ),
                ),
                child: const Text('コピーして編集'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'カスタム',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (provider.customTemplates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('まだカスタムテンプレートがありません'),
            ),
          for (final template in provider.customTemplates)
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(template.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TemplateEditScreen(template: template),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, template),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
