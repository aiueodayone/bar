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
    required this.onLongPress,
    this.onToggleFavorite,
    this.selectionMode = false,
    this.selected = false,
  });

  final Memo memo;
  final Genre? genre;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// 選択モード中は星ボタン自体を出さないので、その間は null でよい。
  final VoidCallback? onToggleFavorite;

  /// 一覧が複数選択モードのとき true。leading をチェックマークに切り替える。
  final bool selectionMode;
  final bool selected;

  /// leading の丸アイコンに出す、そのメモを代表する添付種別のアイコン。
  /// 複数種類が付いていても丸アイコンには1つしか出せないため、
  /// 動画 > 写真 > 音声 > (何も無ければ)テキスト の優先順で決める。
  /// 実際に何が付いているかは trailing の小さいアイコン行で全て分かる。
  IconData get _primaryIcon {
    if (memo.hasVideo) return Icons.videocam;
    if (memo.hasImage) return Icons.photo;
    if (memo.hasAudio) return Icons.mic;
    return Icons.notes;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final preview = memo.content.replaceAll('\n', ' ');
    final displayTitle = memo.title.isNotEmpty
        ? memo.title
        : (preview.isNotEmpty ? preview : '(無題のメモ)');

    // 音声には昔からマイクアイコンがあったが、写真・動画には何も表示が
    // 無く「添付の有無が一覧から分からない」というフィードバックが
    // あった。複数種類が付いている場合は該当するアイコンを並べて出す。
    final attachmentIcons = <IconData>[
      if (memo.hasAudio) Icons.mic,
      if (memo.hasImage) Icons.photo_outlined,
      if (memo.hasVideo) Icons.videocam_outlined,
    ];

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: selected,
      leading: selectionMode
          ? CircleAvatar(
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            )
          : CircleAvatar(
              backgroundColor: genre?.color ?? Colors.grey.shade400,
              child: Icon(_primaryIcon, color: Colors.white, size: 20),
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (memo.isFavorite && selectionMode)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.star, color: Colors.amber, size: 18),
            ),
        ],
      ),
      subtitle: Text(
        memo.title.isNotEmpty && preview.isNotEmpty
            ? preview
            : dateFormat.format(memo.updatedAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!selectionMode)
            IconButton(
              icon: Icon(
                memo.isFavorite ? Icons.star : Icons.star_border,
                color: memo.isFavorite ? Colors.amber : Colors.grey,
              ),
              tooltip: memo.isFavorite ? 'お気に入りを解除' : 'お気に入りに登録',
              onPressed: onToggleFavorite,
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (attachmentIcons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final icon in attachmentIcons)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(
                            icon,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
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
        ],
      ),
    );
  }
}
