import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../data/memo_image_repository.dart';
import '../data/memo_repository.dart';
import '../models/memo.dart';
import '../models/memo_image.dart';
import '../providers/app_settings_provider.dart';
import '../providers/genre_provider.dart';
import '../providers/memo_provider.dart';
import '../services/audio_service.dart';
import '../services/export_service.dart';
import '../services/image_service.dart';
import '../services/playback_service.dart';
import '../services/transcription_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/genre_edit_dialog.dart';
import '../widgets/recording_waveform.dart';

class MemoEditScreen extends StatefulWidget {
  const MemoEditScreen({super.key, this.memoId});

  /// null の場合は新規作成。
  final String? memoId;

  @override
  State<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends State<MemoEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _repository = MemoRepository();
  final _imageRepository = MemoImageRepository();
  final _audioService = AudioService();
  final _imageService = ImageService();
  final _playbackService = PlaybackService();
  final _transcriptionService = TranscriptionService();
  final _exportService = ExportService();
  final _uuid = const Uuid();

  Memo? _original;
  bool _isLoading = true;
  bool _saved = false;
  String? _selectedGenreId;

  String? _audioPath;
  int? _audioDurationMs;
  String? _initialAudioPath;

  bool _isRecording = false;

  List<MemoImage> _images = [];
  List<MemoImage> _initialImages = [];
  Set<String> _initialImageIds = {};
  bool _isPickingImages = false;

  bool _isPlaying = false;
  StreamSubscription<void>? _playbackCompleteSub;

  bool _isTranscribing = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // 再生位置(onPositionChanged)は高頻度に更新されるため、画面全体を
    // 再ビルドしないよう _PlaybackSlider 側で個別に購読・保持する。
    _playbackCompleteSub = _playbackService.onComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    // 本文欄の入力中はキーボードで画面が狭くなるため、添付ボタンの
    // 大きなカードを畳んで邪魔にならないようにする(フォーカスが外れたら
    // 元に戻す)。
    _contentFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    if (widget.memoId != null) {
      final memo = await _repository.fetchMemoById(widget.memoId!);
      if (memo != null) {
        _original = memo;
        _titleController.text = memo.title;
        _contentController.text = memo.content;
        _selectedGenreId = memo.genreId;
        _audioPath = memo.audioPath;
        _audioDurationMs = memo.audioDurationMs;
        _initialAudioPath = memo.audioPath;
        final images = await _imageRepository.fetchImagesForMemo(memo.id);
        _images = List.of(images);
        _initialImages = List.of(images);
        _initialImageIds = images.map((i) => i.id).toSet();
      }
    } else {
      final draft = context.read<MemoProvider>().createDraft();
      _original = draft;
      _selectedGenreId = draft.genreId;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _playbackCompleteSub?.cancel();
    if (!_saved && _audioPath != null && _audioPath != _initialAudioPath) {
      _audioService.deleteFile(_audioPath!);
    }
    if (!_saved) {
      for (final image in _images) {
        if (!_initialImageIds.contains(image.id)) {
          _imageService.deleteFile(image.path);
        }
      }
    }
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _audioService.dispose();
    _playbackService.dispose();
    _transcriptionService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final (path, durationMs) = await _audioService.stop();
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPath = path;
          _audioDurationMs = durationMs;
        }
      });
      return;
    }

    try {
      await _audioService.start();
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('録音を開始できませんでした: $e')));
      }
    }
  }

  Future<void> _confirmDeleteAudio() async {
    if (_audioPath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('録音を削除しますか?'),
        content: const Text('この操作は取り消せません。'),
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
    if (!mounted || confirmed != true) return;
    await _deleteAudio();
  }

  Future<void> _deleteAudio() async {
    if (_audioPath == null) return;
    await _playbackService.stop();
    if (_audioPath != _initialAudioPath) {
      await _audioService.deleteFile(_audioPath!);
    }
    setState(() {
      _audioPath = null;
      _audioDurationMs = null;
      _isPlaying = false;
    });
  }

  Future<void> _togglePlayback() async {
    if (_audioPath == null) return;
    if (_isPlaying) {
      await _playbackService.pause();
      setState(() => _isPlaying = false);
    } else {
      await _playbackService.play(_audioPath!);
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _transcribe() async {
    if (_audioPath == null) return;

    final modelReady = await _transcriptionService.isModelReady();
    if (!mounted) return;
    if (!modelReady) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('文字起こしモデルのダウンロード'),
          content: const Text(
            '初回のみ、オフライン音声認識用の日本語モデル(約50MB)を'
            'ダウンロードします。ダウンロード後は完全にオフラインで'
            '文字起こしできます。\n\n'
            'この文字起こしは端末内で処理されるため、あなたの音声が'
            '外部に送信されたり、AIの学習に使われたりすることはありません。'
            'ダウンロードしますか?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ダウンロード'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      setState(() {
        _isDownloadingModel = true;
        _downloadProgress = 0;
      });
      try {
        await _transcriptionService.ensureModelReady(
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('モデルのダウンロードに失敗しました: $e')));
        }
        setState(() => _isDownloadingModel = false);
        return;
      }
      setState(() => _isDownloadingModel = false);
    }

    setState(() => _isTranscribing = true);
    try {
      final text = await _transcriptionService.transcribeWavFile(_audioPath!);
      if (text.isNotEmpty) {
        final current = _contentController.text;
        _contentController.text = current.isEmpty ? text : '$current\n$text';
        _contentController.selection = TextSelection.collapsed(
          offset: _contentController.text.length,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('文字起こし結果が空でした')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('文字起こしに失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _save() async {
    final original = _original;
    if (original == null) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty &&
        content.isEmpty &&
        _audioPath == null &&
        _images.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final memo = original.copyWith(
      title: title,
      content: content,
      genreId: _selectedGenreId,
      clearGenre: _selectedGenreId == null,
      audioPath: _audioPath,
      audioDurationMs: _audioDurationMs,
      clearAudio: _audioPath == null,
    );

    try {
      await context.read<MemoProvider>().saveMemo(memo);
      await _persistImageChanges();
    } catch (e) {
      // 保存が失敗しても無反応に見えないよう、必ず利用者に伝える。
      // ここで画面を閉じてしまうと入力内容がそのまま失われるので、
      // 閉じずに編集画面に留まらせる(再試行できるように)。
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
      return;
    }

    _saved = true;
    if (mounted) Navigator.of(context).pop();
  }

  /// 編集中に追加・削除した画像を確定させる。既存の画像で一覧から
  /// 消したものは DB 行とファイルの両方を削除し、新しく追加したものは
  /// DB に登録する。
  Future<void> _persistImageChanges() async {
    final currentIds = _images.map((i) => i.id).toSet();
    for (final removed in _initialImages) {
      if (currentIds.contains(removed.id)) continue;
      await _imageRepository.deleteImage(removed.id);
      await _imageService.deleteFile(removed.path);
    }
    for (final image in _images) {
      if (_initialImageIds.contains(image.id)) continue;
      await _imageRepository.insertImage(image);
    }
  }

  Future<void> _pickImages() async {
    final original = _original;
    if (original == null) return;
    // カメラでの撮影(特に動画)はマイクも使うため、音声メモの録音中に
    // 開いてしまうと録音がカメラアプリ側に横取りされて壊れる恐れがある。
    if (_isRecording) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('録音中は写真・動画を追加できません')));
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('写真を撮影'),
              onTap: () => Navigator.of(sheetContext).pop('photo_camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('動画を撮影'),
              onTap: () => Navigator.of(sheetContext).pop('video_camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('写真をギャラリーから選ぶ'),
              onTap: () => Navigator.of(sheetContext).pop('photo_gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('動画をギャラリーから選ぶ'),
              onTap: () => Navigator.of(sheetContext).pop('video_gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _isPickingImages = true);
    try {
      final picked = <XFile>[];
      var type = MemoAttachmentType.image;
      switch (source) {
        case 'photo_camera':
          final file = await _imageService.pickFromCamera();
          if (file != null) picked.add(file);
        case 'video_camera':
          type = MemoAttachmentType.video;
          final file = await _imageService.pickVideoFromCamera();
          if (file != null) picked.add(file);
        case 'video_gallery':
          type = MemoAttachmentType.video;
          final file = await _imageService.pickVideoFromGallery();
          if (file != null) picked.add(file);
        default:
          picked.addAll(await _imageService.pickFromGallery());
      }
      for (final file in picked) {
        final path = await _imageService.importImage(file);
        _images.add(
          MemoImage(
            id: _uuid.v4(),
            memoId: original.id,
            path: path,
            sortOrder: _images.length,
            createdAt: DateTime.now(),
            type: type,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('追加できませんでした: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  Future<void> _removeImage(MemoImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(image.isVideo ? '動画を削除しますか?' : '画像を削除しますか?'),
        content: const Text('この操作は取り消せません。'),
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
    if (!mounted || confirmed != true) return;
    if (!_initialImageIds.contains(image.id)) {
      await _imageService.deleteFile(image.path);
    }
    setState(() => _images.removeWhere((i) => i.id == image.id));
  }

  Future<void> _viewImage(MemoImage image) async {
    // 音声メモを再生中に画像/動画ビューアーを開くと、動画の音声と二重に
    // 鳴ってしまう(動画には自前の音声がある)ため、先に止めておく。
    if (_isPlaying) {
      await _playbackService.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
    if (!mounted) return;
    if (image.isVideo) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _VideoPlayerPage(image.path)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(image.path))),
          ),
        ),
      ),
    );
  }

  Memo _currentMemoSnapshot() {
    return _original!.copyWith(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      audioPath: _audioPath,
      audioDurationMs: _audioDurationMs,
      clearAudio: _audioPath == null,
    );
  }

  Future<void> _shareMemo() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final hasText = title.isNotEmpty || content.isNotEmpty;
    if (!hasText && _audioPath == null) return;

    var choice = 'text';
    if (_audioPath != null && hasText) {
      final picked = await showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('テキストを共有'),
                onTap: () => Navigator.of(sheetContext).pop('text'),
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack_outlined),
                title: const Text('音声ファイルを共有'),
                onTap: () => Navigator.of(sheetContext).pop('audio'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_email_outlined),
                title: const Text('音声とテキストをまとめて共有'),
                subtitle: const Text('メールなどに録音ファイルと文字起こし結果を添付します'),
                onTap: () => Navigator.of(sheetContext).pop('both'),
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      choice = picked;
    } else if (_audioPath != null) {
      choice = 'audio';
    }

    if (!mounted) return;
    final memo = _currentMemoSnapshot();
    switch (choice) {
      case 'audio':
        await _exportService.shareMemoAudio(memo);
        break;
      case 'both':
        final genre = context.read<GenreProvider>().byId(_selectedGenreId);
        await _exportService.shareMemoAudioWithText(memo, genre);
        break;
      default:
        final genre = context.read<GenreProvider>().byId(_selectedGenreId);
        await _exportService.shareMemoText(memo, genre);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('このメモを削除しますか?'),
        content: const Text('削除済みボックスに移動します。5日以内なら設定画面から復元できます。'),
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
    if (!mounted) return;
    if (confirmed ?? false) {
      _saved = true;
      await context.read<MemoProvider>().deleteMemo(widget.memoId!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final genreProvider = context.watch<GenreProvider>();
    final adsRemoved = context.watch<AppSettingsProvider>().adsRemoved;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 戻る操作(システムのバックジェスチャー・戻るボタン)でも、
        // チェックマークをタップしたのと同じように保存する。そうしないと
        // 「保存し忘れて戻ったら内容が消えていた」という事故になりうる。
        _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.memoId == null ? '新規メモ' : 'メモを編集'),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: '共有',
              onPressed: _shareMemo,
            ),
            if (widget.memoId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            IconButton(icon: const Icon(Icons.check), onPressed: _save),
          ],
        ),
        body: GestureDetector(
          // 本文欄などの外側をタップしたらキーボードを閉じる。デフォルトの
          // ままだと、一度入力を始めるとキーボードを下げる手段が
          // (戻る操作くらいしか)無かったため。
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('未分類'),
                          selected: _selectedGenreId == null,
                          onSelected: (_) =>
                              setState(() => _selectedGenreId = null),
                        ),
                        for (final genre in genreProvider.genres)
                          ChoiceChip(
                            avatar: CircleAvatar(
                              backgroundColor: genre.color,
                              radius: 6,
                            ),
                            label: Text(genre.name),
                            selected: _selectedGenreId == genre.id,
                            onSelected: (_) =>
                                setState(() => _selectedGenreId = genre.id),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('新規ジャンル'),
                          onPressed: () async {
                            final created = await showGenreEditDialog(context);
                            if (created != null && mounted) {
                              setState(() => _selectedGenreId = created.id);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'タイトル',
                        border: InputBorder.none,
                      ),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              // 本文欄は外側を ListView にせず、ここだけ独立してスクロール
              // させる。文字量が多いメモで、外側のスクロール領域の高さ計算に
              // 本文の再レイアウトが毎回波及しないようにするため。
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    decoration: const InputDecoration(
                      hintText: '内容を入力…',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImagesSection(
                      context,
                      compact: _contentFocusNode.hasFocus,
                    ),
                    const SizedBox(height: 8),
                    _buildAudioSection(
                      context,
                      compact: _contentFocusNode.hasFocus,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // body の Column ではなく bottomNavigationBar に置く。録音ボタンの
        // すぐ下に固定表示されつつ、Scaffold のレイアウト計算に乗るため、
        // 広告の読み込みタイミングで録音ボタンの位置がずれることもない。
        bottomNavigationBar: adsRemoved ? null : const BannerAdWidget(),
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context, {required bool compact}) {
    // 「音声メモを録音」ボタン(_buildAudioSection の空状態)と見た目を
    // 揃える: Card の中に、丸いアイコン+ラベルを1つのタップ領域として
    // 置く。
    if (_images.isEmpty && !_isPickingImages) {
      // 本文入力中はキーボードで画面が狭くなるので、何も付いていない
      // ときの「追加を誘う」カードは畳んで場所を空ける。
      if (compact) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: _pickImages,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('写真・動画を追加'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final image in _images)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _viewImage(image),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: image.isVideo
                              ? Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.black87,
                                  child: const Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                )
                              : Image.file(
                                  File(image.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton(
                          icon: const Icon(Icons.cancel),
                          iconSize: 20,
                          color: Colors.black54,
                          onPressed: () => _removeImage(image),
                        ),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: _isPickingImages ? null : _pickImages,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isPickingImages
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioSection(BuildContext context, {required bool compact}) {
    // 本文入力中はキーボードで画面が狭くなるので、何も録っていない/
    // ダウンロード中でもないときの「録音を誘う」カードは畳んで場所を
    // 空ける。録音中やダウンロード中は操作(停止ボタン等)が必要なので
    // 畳まない。
    if (compact &&
        !_isDownloadingModel &&
        _audioPath == null &&
        !_isRecording) {
      return const SizedBox.shrink();
    }
    if (_isDownloadingModel) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('文字起こしモデルをダウンロード中…'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 4),
              Text('${(_downloadProgress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_audioPath != null) ...[
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    ),
                    iconSize: 36,
                    onPressed: _togglePlayback,
                  ),
                  Expanded(
                    child: _PlaybackSlider(playbackService: _playbackService),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '録音を削除',
                    onPressed: _confirmDeleteAudio,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _isTranscribing ? null : _transcribe,
                  icon: _isTranscribing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.subtitles_outlined),
                  label: Text(_isTranscribing ? '文字起こし中…' : '文字起こしする(オフライン)'),
                ),
              ),
            ] else if (_isRecording)
              _RecordingControls(
                audioService: _audioService,
                onStop: _toggleRecording,
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _toggleRecording,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.mic,
                            size: 32,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('音声メモを録音'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 録音中の表示(経過時間・波形)を担う。振幅は約200msごとに更新されるため、
/// [MemoEditScreen] 全体ではなくこのウィジェットだけを再ビルドすることで、
/// 録音中にテキスト入力欄などを含む画面全体が毎回再構築されるのを避ける。
class _RecordingControls extends StatefulWidget {
  const _RecordingControls({required this.audioService, required this.onStop});

  final AudioService audioService;
  final VoidCallback onStop;

  @override
  State<_RecordingControls> createState() => _RecordingControlsState();
}

class _RecordingControlsState extends State<_RecordingControls> {
  Duration _elapsed = Duration.zero;
  List<double> _waveformLevels = [];
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void initState() {
    super.initState();
    _tick();
    _amplitudeSub = widget.audioService.amplitudeStream().listen((amplitude) {
      if (!mounted) return;
      // dBFS(だいたい -50〜0)を 0.0〜1.0 の高さに正規化する。
      final level = ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
      setState(() {
        // RecordingWaveform の CustomPainter は shouldRepaint で levels を
        // 参照比較しているため、既存のリストを in-place で書き換えると
        // 「同じインスタンスのまま」になり変化が検出されず、波形が最初の
        // 1本で止まって見えてしまう。新しいリストを作って差し替える。
        final updated = [..._waveformLevels, level];
        _waveformLevels = updated.length > 80
            ? updated.sublist(updated.length - 80)
            : updated;
      });
    });
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      _tick();
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              icon: const Icon(Icons.stop),
              iconSize: 32,
              style: IconButton.styleFrom(backgroundColor: Colors.red),
              onPressed: widget.onStop,
            ),
            const SizedBox(width: 12),
            Text('録音中… ${_formatDuration(_elapsed)}'),
          ],
        ),
        const SizedBox(height: 8),
        RecordingWaveform(levels: _waveformLevels),
      ],
    );
  }
}

/// 再生位置バー。onPositionChanged は再生中高頻度に発火するため、
/// [MemoEditScreen] 全体ではなくこの小さなウィジェットだけを再ビルドする。
class _PlaybackSlider extends StatefulWidget {
  const _PlaybackSlider({required this.playbackService});

  final PlaybackService playbackService;

  @override
  State<_PlaybackSlider> createState() => _PlaybackSliderState();
}

class _PlaybackSliderState extends State<_PlaybackSlider> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    _positionSub = widget.playbackService.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durationSub = widget.playbackService.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds == 0 ? 1 : _duration.inMilliseconds;
    return Slider(
      value: _position.inMilliseconds.clamp(0, maxMs).toDouble(),
      max: maxMs.toDouble(),
      onChanged: (v) =>
          widget.playbackService.seek(Duration(milliseconds: v.toInt())),
    );
  }
}

/// 添付動画をフルスクリーンで再生する画面。開くと自動再生し、タップで
/// 再生/一時停止を切り替える。
class _VideoPlayerPage extends StatefulWidget {
  const _VideoPlayerPage(this.path);

  final String path;

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _ready
            ? GestureDetector(
                onTap: _togglePlayback,
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          if (_controller.value.isPlaying) {
                            return const SizedBox.shrink();
                          }
                          return const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white70,
                            size: 72,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
