import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/memo_repository.dart';
import '../models/memo.dart';
import '../providers/genre_provider.dart';
import '../providers/memo_provider.dart';
import '../services/audio_service.dart';
import '../services/playback_service.dart';
import '../services/transcription_service.dart';

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
  final _repository = MemoRepository();
  final _audioService = AudioService();
  final _playbackService = PlaybackService();
  final _transcriptionService = TranscriptionService();

  Memo? _original;
  bool _isLoading = true;
  bool _saved = false;
  String? _selectedGenreId;

  String? _audioPath;
  int? _audioDurationMs;
  String? _initialAudioPath;

  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;

  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  bool _isTranscribing = false;
  bool _isDownloadingModel = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _playbackService.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _playbackPosition = pos);
    });
    _playbackService.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playbackDuration = dur);
    });
    _playbackService.onComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
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
    if (!_saved && _audioPath != null && _audioPath != _initialAudioPath) {
      _audioService.deleteFile(_audioPath!);
    }
    _titleController.dispose();
    _contentController.dispose();
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
      setState(() {
        _isRecording = true;
        _recordingElapsed = Duration.zero;
      });
      _tickRecordingTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('録音を開始できませんでした: $e')),
        );
      }
    }
  }

  void _tickRecordingTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;
      setState(() {
        _recordingElapsed += const Duration(seconds: 1);
      });
      _tickRecordingTimer();
    });
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
            '文字起こしできます。ダウンロードしますか?',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('モデルのダウンロードに失敗しました: $e')),
          );
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
        _contentController.text =
            current.isEmpty ? text : '$current\n$text';
        _contentController.selection = TextSelection.collapsed(
          offset: _contentController.text.length,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文字起こし結果が空でした')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文字起こしに失敗しました: $e')),
        );
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
    if (title.isEmpty && content.isEmpty && _audioPath == null) {
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
    );

    _saved = true;
    await context.read<MemoProvider>().saveMemo(memo);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('このメモを削除しますか?'),
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final genreProvider = context.watch<GenreProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memoId == null ? '新規メモ' : 'メモを編集'),
        actions: [
          if (widget.memoId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('未分類'),
                selected: _selectedGenreId == null,
                onSelected: (_) => setState(() => _selectedGenreId = null),
              ),
              for (final genre in genreProvider.genres)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: genre.color, radius: 6),
                  label: Text(genre.name),
                  selected: _selectedGenreId == genre.id,
                  onSelected: (_) =>
                      setState(() => _selectedGenreId = genre.id),
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
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              hintText: '内容を入力…',
              border: InputBorder.none,
            ),
            maxLines: null,
            minLines: 6,
          ),
          const SizedBox(height: 16),
          _buildAudioSection(context),
        ],
      ),
    );
  }

  Widget _buildAudioSection(BuildContext context) {
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
                    icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
                    iconSize: 36,
                    onPressed: _togglePlayback,
                  ),
                  Expanded(
                    child: Slider(
                      value: _playbackPosition.inMilliseconds
                          .clamp(0, _playbackDuration.inMilliseconds == 0
                              ? 1
                              : _playbackDuration.inMilliseconds)
                          .toDouble(),
                      max: _playbackDuration.inMilliseconds == 0
                          ? 1
                          : _playbackDuration.inMilliseconds.toDouble(),
                      onChanged: (v) =>
                          _playbackService.seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteAudio,
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
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : null,
                    ),
                    onPressed: _toggleRecording,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isRecording
                        ? '録音中… ${_formatDuration(_recordingElapsed)}'
                        : '音声メモを録音',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
