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
    const trackHeight = 4.0;
    final segments = (size.width / 40).round().clamp(6, 16);
    final segmentWidth = (size.width - gap * (segments - 1)) / segments;
    final completedWidth = progress * size.width;
    for (var index = 0; index < segments; index++) {
      final left = index * (segmentWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          (size.height - trackHeight) / 2,
          segmentWidth,
          trackHeight,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = colors.track);

      final filledWidth = (completedWidth - left).clamp(0.0, segmentWidth);
      if (filledWidth <= 0) continue;
      canvas.save();
      canvas.clipRRect(rect);
      canvas.drawRect(
        Rect.fromLTWH(
          left,
          (size.height - trackHeight) / 2,
          filledWidth,
          trackHeight,
        ),
        Paint()..color = color ?? colors.accent,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TransferTrackPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors ||
      oldDelegate.color != color;
}
