import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/genre.dart';
import '../providers/genre_provider.dart';
import '../widgets/genre_edit_dialog.dart';

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
                        onPressed: () =>
                            showGenreEditDialog(context, genre: genre),
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
        onPressed: () => showGenreEditDialog(context),
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

}
