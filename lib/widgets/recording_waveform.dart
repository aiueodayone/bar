import 'package:flutter/material.dart';

/// 録音中にマイクの振幅をバー状の波形として表示するウィジェット。
/// [levels] は 0.0〜1.0 に正規化された振幅値を、古い順に並べたもの。
class RecordingWaveform extends StatelessWidget {
  const RecordingWaveform({
    super.key,
    required this.levels,
    this.height = 40,
    this.barColor,
  });

  final List<double> levels;
  final double height;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final color = barColor ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(levels: levels, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;

    const barWidth = 3.0;
    const gap = 2.0;
    final slot = barWidth + gap;
    final maxBars = (size.width / slot).floor();
    final visible = levels.length > maxBars
        ? levels.sublist(levels.length - maxBars)
        : levels;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final startX = size.width - visible.length * slot;
    for (var i = 0; i < visible.length; i++) {
      final level = visible[i].clamp(0.0, 1.0);
      final barHeight = (size.height * level).clamp(2.0, size.height);
      final x = startX + i * slot + barWidth / 2;
      final centerY = size.height / 2;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.levels != levels || oldDelegate.color != color;
  }
}
