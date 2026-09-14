import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/genre.dart';
import '../providers/genre_provider.dart';

const List<Color> kGenreColors = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.amber,
  Colors.orange,
  Colors.brown,
  Colors.blueGrey,
];

/// ジャンルの新規作成・編集ダイアログを表示する。
/// 保存された場合は作成/更新後の [Genre] を、キャンセル時は null を返す。
Future<Genre?> showGenreEditDialog(BuildContext context, {Genre? genre}) {
  final genreProvider = context.read<GenreProvider>();
  final controller = TextEditingController(text: genre?.name ?? '');
  var selectedColor = genre?.color ?? kGenreColors.first;

  return showDialog<Genre?>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(genre == null ? '新しいジャンル' : 'ジャンルを編集'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'ジャンル名'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in kGenreColors)
                      GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 16,
                          child: selectedColor.toARGB32() == color.toARGB32()
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  final Genre saved;
                  if (genre == null) {
                    saved = await genreProvider.addGenre(name, selectedColor);
                  } else {
                    await genreProvider.renameGenre(
                      genre,
                      name,
                      selectedColor,
                    );
                    saved = genre.copyWith(name: name, color: selectedColor);
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(saved);
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}
