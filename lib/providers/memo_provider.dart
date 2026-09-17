import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/memo_repository.dart';
import '../models/memo.dart';

/// メモ一覧・検索・ジャンル絞り込みの状態を管理する。
class MemoProvider extends ChangeNotifier {
  MemoProvider({MemoRepository? repository})
    : _repository = repository ?? MemoRepository();

  final MemoRepository _repository;
  final _uuid = const Uuid();

  List<Memo> _memos = [];
  List<Memo> get memos => List.unmodifiable(_memos);

  String? _genreFilter;
  String? get genreFilter => _genreFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Timer? _debounce;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _memos = await _repository.fetchMemos(
      genreId: _genreFilter,
      searchQuery: _searchQuery,
    );
    _isLoading = false;
    notifyListeners();
  }

  void setGenreFilter(String? genreId) {
    _genreFilter = genreId;
    load();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), load);
    notifyListeners();
  }

  Memo createDraft() {
    final now = DateTime.now();
    return Memo(
      id: _uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      genreId: _genreFilter == 'unassigned' ? null : _genreFilter,
    );
  }

  Future<void> saveMemo(Memo memo) async {
    await _repository.upsertMemo(memo.copyWith(updatedAt: DateTime.now()));
    await load();
  }

  Future<void> deleteMemo(String id) async {
    // メモのDB行だけ消して録音ファイルを放置すると、削除するたびに
    // 使われない .wav ファイルがストレージに溜まり続けてしまう。
    final memo = await _repository.fetchMemoById(id);
    await _repository.deleteMemo(id);
    if (memo != null && memo.hasAudio) {
      final file = File(memo.audioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
