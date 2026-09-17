import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../providers/app_settings_provider.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('テーマ(着せ替え)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!settings.themesUnlocked) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'テーマパックを購入すると、追加のカラーテーマが\n'
                      '全て使い放題になります(買い切り)。',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: settings.canPurchaseThemePack
                          ? () => settings.buyThemePack()
                          : null,
                      child: Text(
                        settings.canPurchaseThemePack
                            ? 'テーマパックを購入 (${settings.themePackPrice ?? ''})'
                            : 'ストア接続を確認できませんでした',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: kAppThemes.length,
            itemBuilder: (context, index) {
              final theme = kAppThemes[index];
              final locked = theme.isPremium && !settings.themesUnlocked;
              final selected = settings.currentTheme.id == theme.id;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (locked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('このテーマはテーマパック購入後に使用できます')),
                    );
                    return;
                  }
                  settings.selectTheme(theme);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? theme.seedColor
                          : Colors.grey.withValues(alpha: 0.3),
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.seedColor,
                            radius: 20,
                            child: locked
                                ? const Icon(
                                    Icons.lock,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : (selected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : null),
                          ),
                          const SizedBox(height: 8),
                          Text(theme.name),
                        ],
                      ),
                      if (theme.isPremium)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
