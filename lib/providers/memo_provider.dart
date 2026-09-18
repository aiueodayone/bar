import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/memo_repository.dart';
import '../models/memo.dart';

/// ごみ箱に入れたメモを保持しておく期間。これを過ぎると自動的に完全削除
/// される。
const Duration kTrashRetention = Duration(days: 5);

/// メモ一覧・検索・ジャンル絞り込み・ごみ箱の状態を管理する。
class MemoProvider extends ChangeNotifier {
  MemoProvider({MemoRepository? repository})
    : _repository = repository ?? MemoRepository();

  final MemoRepository _repository;
  final _uuid = const Uuid();

  List<Memo> _memos = [];
  List<Memo> get memos => List.unmodifiable(_memos);

  List<Memo> _trashedMemos = [];
  List<Memo> get trashedMemos => List.unmodifiable(_trashedMemos);

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

  Future<void> loadTrash() async {
    _trashedMemos = await _repository.fetchTrashedMemos();
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

  /// メモをごみ箱に移動する(すぐには消えず、[kTrashRetention] の間は
  /// 「削除済み」から復元できる)。
  Future<void> deleteMemo(String id) => moveToTrash([id]);

  /// 一覧画面での複数選択削除用。
  Future<void> moveToTrash(List<String> ids) async {
    await _repository.softDeleteMemos(ids);
    await load();
  }

  Future<void> restoreFromTrash(String id) async {
    await _repository.restoreMemo(id);
    await loadTrash();
    await load();
  }

  /// ごみ箱から完全に削除する(録音ファイルも削除する)。取り消せない。
  Future<void> permanentlyDelete(String id) async {
    final memo = await _repository.fetchMemoById(id);
    await _repository.deleteMemo(id);
    if (memo != null && memo.hasAudio) {
      final file = File(memo.audioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await loadTrash();
  }

  /// [kTrashRetention] を過ぎたごみ箱内のメモを完全に削除する。
  /// アプリ起動時に一度呼ぶ想定。
  Future<void> purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(kTrashRetention);
    final expired = await _repository.fetchExpiredTrash(cutoff);
    for (final memo in expired) {
      await _repository.deleteMemo(memo.id);
      if (memo.hasAudio) {
        final file = File(memo.audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
