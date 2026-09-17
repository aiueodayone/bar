import 'package:flutter/material.dart';

/// アプリの配色テーマ(着せ替え)。
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.seedColor,
    this.isPremium = false,
  });

  final String id;
  final String name;
  final Color seedColor;

  /// true の場合はテーマパック購入者のみ選択できる。
  final bool isPremium;
}

/// 標準(無料)テーマのID。ベースは白基調。
const String kDefaultThemeId = 'white';

/// 選択可能なテーマの一覧。
///
/// 現在ある色はすべて無料。テーマパックの課金(isPremium: true)は、
/// 今後のアップデートでより作り込んだ追加テーマを出すときのための
/// 仕組みとして残してあるだけで、今はどのテーマにも使っていない。
const List<AppTheme> kAppThemes = [
  AppTheme(id: 'white', name: 'ホワイト(標準)', seedColor: Colors.teal),
  AppTheme(id: 'sakura', name: 'サクラ', seedColor: Colors.pink),
  AppTheme(id: 'night', name: '夜空', seedColor: Colors.indigo),
  AppTheme(id: 'forest', name: '森', seedColor: Colors.green),
  AppTheme(id: 'sunset', name: 'サンセット', seedColor: Colors.deepOrange),
];

AppTheme findThemeById(String id) {
  return kAppThemes.firstWhere(
    (t) => t.id == id,
    orElse: () => kAppThemes.first,
  );
}
