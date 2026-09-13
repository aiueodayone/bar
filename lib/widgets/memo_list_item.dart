import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/genre.dart';
import '../models/memo.dart';

class MemoListItem extends StatelessWidget {
  const MemoListItem({
    super.key,
    required this.memo,
    required this.genre,
    required this.onTap,
  });

  final Memo memo;
  final Genre? genre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final preview = memo.content.replaceAll('\n', ' ');
    final displayTitle = memo.title.isNotEmpty
        ? memo.title
        : (preview.isNotEmpty ? preview : '(無題のメモ)');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: genre?.color ?? Colors.grey.shade400,
        child: Icon(
          memo.hasAudio ? Icons.mic : Icons.notes,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        memo.title.isNotEmpty && preview.isNotEmpty ? preview : dateFormat.format(memo.updatedAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            dateFormat.format(memo.updatedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (genre != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                genre!.name,
                style: TextStyle(
                  color: genre!.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
