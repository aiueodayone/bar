import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meeting_template.dart';
import '../providers/app_settings_provider.dart';
import '../providers/genre_provider.dart';
import '../providers/memo_provider.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/genre_filter_bar.dart';
import '../widgets/memo_list_item.dart';
import 'genre_management_screen.dart';
import 'memo_edit_screen.dart';
import 'settings_screen.dart';
import 'template_picker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoProvider = context.watch<MemoProvider>();
    final genreProvider = context.watch<GenreProvider>();
    final adsRemoved = context.watch<AppSettingsProvider>().adsRemoved;

    return Scaffold(
      appBar: AppBar(
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
            : const Text('メモ帳'),
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
              MaterialPageRoute(
                builder: (_) => const GenreManagementScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: memoProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : memoProvider.memos.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemCount: memoProvider.memos.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final memo = memoProvider.memos[index];
                          return MemoListItem(
                            memo: memo,
                            genre: genreProvider.byId(memo.genreId),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemoEditScreen(memoId: memo.id),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (!adsRemoved) const BannerAdWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('空のメモを作成'),
              onTap: () => Navigator.of(sheetContext).pop('blank'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('議事録を作成(テンプレートから)'),
              onTap: () => Navigator.of(sheetContext).pop('template'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'blank') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MemoEditScreen()),
      );
      return;
    }

    final template = await Navigator.of(context).push<MeetingTemplate>(
      MaterialPageRoute(builder: (_) => const TemplatePickerScreen()),
    );
    if (template == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoEditScreen(
          initialTitle: template.name,
          initialContent: template.body,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notes, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'メモがありません\n右下の + からテキストや音声メモを作成できます',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
