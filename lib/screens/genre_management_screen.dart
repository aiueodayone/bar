import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/genre.dart';
import '../providers/genre_provider.dart';

const List<Color> _kGenreColors = [
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

class GenreManagementScreen extends StatelessWidget {
  const GenreManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final genreProvider = context.watch<GenreProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('ジャンル管理')),
      body: genreProvider.genres.isEmpty
          ? const Center(child: Text('ジャンルがまだありません'))
          : ListView.builder(
              itemCount: genreProvider.genres.length,
              itemBuilder: (context, index) {
                final genre = genreProvider.genres[index];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: genre.color),
                  title: Text(genre.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(context, genre: genre),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, genre),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Genre genre) async {
    final genreProvider = context.read<GenreProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ジャンルを削除しますか?'),
        content: Text(
          '「${genre.name}」を削除します。このジャンルのメモは未分類になります。',
        ),
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
      await genreProvider.deleteGenre(genre.id);
    }
  }

  Future<void> _showEditDialog(BuildContext context, {Genre? genre}) async {
    final genreProvider = context.read<GenreProvider>();
    final controller = TextEditingController(text: genre?.name ?? '');
    Color selectedColor = genre?.color ?? _kGenreColors.first;

    await showDialog<void>(
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
                      for (final color in _kGenreColors)
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
                    if (genre == null) {
                      await genreProvider.addGenre(name, selectedColor);
                    } else {
                      await genreProvider.renameGenre(
                        genre,
                        name,
                        selectedColor,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
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
}
