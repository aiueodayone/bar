import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/memo.dart';
import '../providers/app_settings_provider.dart';
import '../providers/genre_provider.dart';
import '../providers/memo_provider.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/genre_filter_bar.dart';
import '../widgets/memo_list_item.dart';
import 'genre_management_screen.dart';
import 'memo_edit_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  // 一覧からの複数選択削除。空でなければ選択モード。
  final Set<String> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _showAttachmentFilterDialog(MemoProvider memoProvider) async {
    var audio = memoProvider.attachmentFilters.contains(
      MemoAttachmentFilter.audio,
    );
    var image = memoProvider.attachmentFilters.contains(
      MemoAttachmentFilter.image,
    );
    var video = memoProvider.attachmentFilters.contains(
      MemoAttachmentFilter.video,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添付で絞り込み'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: audio,
                title: const Text('音声入りのメモ'),
                onChanged: (v) => setDialogState(() => audio = v ?? false),
              ),
              CheckboxListTile(
                value: image,
                title: const Text('画像入りのメモ'),
                onChanged: (v) => setDialogState(() => image = v ?? false),
              ),
              CheckboxListTile(
                value: video,
                title: const Text('動画入りのメモ'),
                onChanged: (v) => setDialogState(() => video = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  audio = false;
                  image = false;
                  video = false;
                });
              },
              child: const Text('クリア'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('適用'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    memoProvider.setAttachmentFilters({
      if (audio) MemoAttachmentFilter.audio,
      if (image) MemoAttachmentFilter.image,
      if (video) MemoAttachmentFilter.video,
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$count件のメモを削除しますか?'),
        content: const Text('削除済みボックスに移動します。5日以内なら設定画面から復元できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = _selectedIds.toList();
    _clearSelection();
    if (!mounted) return;
    await context.read<MemoProvider>().moveToTrash(ids);
  }

  @override
  Widget build(BuildContext context) {
    final memoProvider = context.watch<MemoProvider>();
    final genreProvider = context.watch<GenreProvider>();
    final adsRemoved = context.watch<AppSettingsProvider>().adsRemoved;

    return Scaffold(
      appBar: _isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length}件選択中'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '削除',
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: _searching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'メモを検索',
                        border: InputBorder.none,
                      ),
                      onChanged: memoProvider.setSearchQuery,
                    )
                  : const Text('手もとメモ'),
              actions: [
                IconButton(
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _searchController.clear();
                        memoProvider.setSearchQuery('');
                      }
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    memoProvider.favoritesOnly ? Icons.star : Icons.star_border,
                    color: memoProvider.favoritesOnly ? Colors.amber : null,
                  ),
                  tooltip: memoProvider.favoritesOnly
                      ? 'すべてのメモを表示'
                      : 'お気に入りのみ表示',
                  onPressed: () => memoProvider.setFavoritesOnly(
                    !memoProvider.favoritesOnly,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    memoProvider.attachmentFilters.isEmpty
                        ? Icons.filter_list
                        : Icons.filter_list_alt,
                    color: memoProvider.attachmentFilters.isEmpty
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: '添付で絞り込み',
                  onPressed: () => _showAttachmentFilterDialog(memoProvider),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          GenreFilterBar(
            genres: genreProvider.genres,
            selectedGenreId: memoProvider.genreFilter,
            onSelected: memoProvider.setGenreFilter,
            onManageGenres: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GenreManagementScreen()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: memoProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : memoProvider.memos.isEmpty
                ? _EmptyState(
                    favoritesOnly: memoProvider.favoritesOnly,
                    attachmentFilterActive:
                        memoProvider.attachmentFilters.isNotEmpty,
                  )
                : ListView.separated(
                    itemCount: memoProvider.memos.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final memo = memoProvider.memos[index];
                      return MemoListItem(
                        memo: memo,
                        genre: genreProvider.byId(memo.genreId),
                        selectionMode: _isSelecting,
                        selected: _selectedIds.contains(memo.id),
                        onToggleFavorite: () =>
                            memoProvider.toggleFavorite(memo),
                        onTap: () {
                          if (_isSelecting) {
                            _toggleSelection(memo.id);
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MemoEditScreen(memoId: memo.id),
                            ),
                          );
                        },
                        onLongPress: () => _toggleSelection(memo.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      // バナー広告は body の Column に含めず bottomNavigationBar に置く。
      // こうすると Scaffold が FloatingActionButton をその上に自動で
      // 余白を取って配置してくれるので、「+」ボタンが広告と重なる問題が
      // 起きない(body 内に広告を置くと、FAB は body の座標系ではなく
      // Scaffold 全体を基準に浮くため、広告と重なってしまう)。
      bottomNavigationBar: adsRemoved ? null : const BannerAdWidget(),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MemoEditScreen())),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.favoritesOnly,
    this.attachmentFilterActive = false,
  });

  final bool favoritesOnly;
  final bool attachmentFilterActive;

  @override
  Widget build(BuildContext context) {
    final message = attachmentFilterActive
        ? '絞り込み条件に一致するメモがありません\nAppBar の絞り込みアイコンから条件を変更できます'
        : favoritesOnly
        ? 'お気に入りのメモがありません\n一覧の星マークをタップすると登録できます'
        : 'メモがありません\n右下の + からテキストや音声メモを作成できます';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attachmentFilterActive
                  ? Icons.filter_list_off
                  : favoritesOnly
                  ? Icons.star_border
                  : Icons.notes,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
