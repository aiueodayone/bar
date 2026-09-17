import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/genre_repository.dart';
import '../models/genre.dart';

/// ジャンル一覧の状態を管理する。
class GenreProvider extends ChangeNotifier {
  GenreProvider({GenreRepository? repository})
    : _repository = repository ?? GenreRepository();

  final GenreRepository _repository;
  final _uuid = const Uuid();

  List<Genre> _genres = [];
  List<Genre> get genres => List.unmodifiable(_genres);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _genres = await _repository.fetchGenres();
    _isLoading = false;
    notifyListeners();
  }

  Genre? byId(String? id) {
    if (id == null) return null;
    for (final genre in _genres) {
      if (genre.id == id) return genre;
    }
    return null;
  }

  Future<Genre> addGenre(String name, Color color) async {
    final genre = Genre(id: _uuid.v4(), name: name, color: color);
    final order = await _repository.nextSortOrder();
    await _repository.upsertGenre(genre, sortOrder: order);
    await load();
    return genre;
  }

  Future<void> renameGenre(Genre genre, String newName, Color newColor) async {
    final updated = genre.copyWith(name: newName, color: newColor);
    await _repository.updateGenre(updated);
    await load();
  }

  Future<void> deleteGenre(String id) async {
    await _repository.deleteGenre(id);
    await load();
  }
}
