import 'package:flutter/material.dart';

import '../models/genre.dart';

/// ホーム画面上部に表示するジャンル絞り込みチップ一覧。
/// selectedGenreId: null = すべて, 'unassigned' = 未分類, それ以外はジャンルID。
class GenreFilterBar extends StatelessWidget {
  const GenreFilterBar({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.onSelected,
    required this.onManageGenres,
  });

  final List<Genre> genres;
  final String? selectedGenreId;
  final ValueChanged<String?> onSelected;
  final VoidCallback onManageGenres;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildChip(context, label: 'すべて', value: null),
          const SizedBox(width: 8),
          _buildChip(context, label: '未分類', value: 'unassigned'),
          for (final genre in genres) ...[
            const SizedBox(width: 8),
            _buildChip(
              context,
              label: genre.name,
              value: genre.id,
              color: genre.color,
            ),
          ],
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.settings, size: 18),
            label: const Text('ジャンル管理'),
            onPressed: onManageGenres,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required String? value,
    Color? color,
  }) {
    final selected = selectedGenreId == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      avatar: color != null
          ? CircleAvatar(backgroundColor: color, radius: 6)
          : null,
      onSelected: (_) => onSelected(value),
    );
  }
}
