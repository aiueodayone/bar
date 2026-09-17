import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
        ],
      ),
      // バナー広告は body の Column に含めず bottomNavigationBar に置く。
      // こうすると Scaffold が FloatingActionButton をその上に自動で
      // 余白を取って配置してくれるので、「+」ボタンが広告と重なる問題が
      // 起きない(body 内に広告を置くと、FAB は body の座標系ではなく
      // Scaffold 全体を基準に浮くため、広告と重なってしまう)。
      bottomNavigationBar: adsRemoved ? null : const BannerAdWidget(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MemoEditScreen())),
        child: const Icon(Icons.add),
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
