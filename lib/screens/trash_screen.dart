import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/memo.dart';
import '../providers/memo_provider.dart';

/// 「削除済み」ボックス。ごみ箱に入れたメモを、保存期限([kTrashRetention])
/// が来るまでの間、復元・完全削除できる。
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MemoProvider>().loadTrash();
  }

  Future<void> _restore(Memo memo) async {
    await context.read<MemoProvider>().restoreFromTrash(memo.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('メモを復元しました')));
  }

  Future<void> _permanentlyDelete(Memo memo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('完全に削除しますか?'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await context.read<MemoProvider>().permanentlyDelete(memo.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('完全に削除しました')));
  }

  String _expiryText(Memo memo) {
    final expiresAt = memo.deletedAt!.add(kTrashRetention);
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inHours < 24) {
      return 'まもなく完全に削除されます';
    }
    return 'あと${remaining.inDays}日で完全に削除されます';
  }

  @override
  Widget build(BuildContext context) {
    final trashed = context.watch<MemoProvider>().trashedMemos;
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('削除済み')),
      body: trashed.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '削除済みボックスは空です',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          : ListView.separated(
              itemCount: trashed.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final memo = trashed[index];
                final preview = memo.content.replaceAll('\n', ' ');
                final displayTitle = memo.title.isNotEmpty
                    ? memo.title
                    : (preview.isNotEmpty ? preview : '(無題のメモ)');
                return ListTile(
                  title: Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_expiryText(memo)}\n'
                    '削除日時: ${dateFormat.format(memo.deletedAt!)}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore_from_trash_outlined),
                        tooltip: '復元',
                        onPressed: () => _restore(memo),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever_outlined),
                        tooltip: '完全に削除',
                        onPressed: () => _permanentlyDelete(memo),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
