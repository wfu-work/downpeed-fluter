import 'package:flutter/material.dart';

import '../../configs/theme/downpeed_theme_tokens.dart';

class TransferTrack extends StatelessWidget {
  const TransferTrack({super.key, this.progress = 0.42, this.color});

  final double progress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Transfer progress ${(progress * 100).round()}%',
      value: '${(progress * 100).round()}%',
      child: SizedBox(
        height: 18,
        child: CustomPaint(
          painter: _TransferTrackPainter(
            progress: progress.clamp(0, 1),
            colors: context.downpeedColors,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _TransferTrackPainter extends CustomPainter {
  const _TransferTrackPainter({
    required this.progress,
    required this.colors,
    this.color,
  });

  final double progress;
  final DownpeedResolvedColors colors;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    const segments = 11;
    final segmentWidth = (size.width - gap * (segments - 1)) / segments;
    final completed = progress * segments;
    for (var index = 0; index < segments; index++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(index * (segmentWidth + gap), 7, segmentWidth, 4),
        const Radius.circular(2),
      );
      final paint = Paint()
        ..color = index < completed ? color ?? colors.accent : colors.track;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TransferTrackPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.color != color;
}
