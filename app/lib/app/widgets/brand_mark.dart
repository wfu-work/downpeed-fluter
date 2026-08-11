import 'package:flutter/material.dart';

import '../../configs/theme/downpeed_theme_tokens.dart';

class DownpeedBrandMark extends StatelessWidget {
  const DownpeedBrandMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Downpeed',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DownpeedBrandPainter(context.downpeedColors),
        ),
      ),
    );
  }
}

class _DownpeedBrandPainter extends CustomPainter {
  const _DownpeedBrandPainter(this.colors);

  final DownpeedResolvedColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final markPaint = Paint()
      ..color = colors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final upperTrack = Path()
      ..moveTo(width * 0.13, height * 0.22)
      ..lineTo(width * 0.42, height * 0.22)
      ..cubicTo(
        width * 0.53,
        height * 0.22,
        width * 0.58,
        height * 0.28,
        width * 0.66,
        height * 0.36,
      )
      ..lineTo(width * 0.70, height * 0.40);
    final lowerTrack = Path()
      ..moveTo(width * 0.13, height * 0.78)
      ..lineTo(width * 0.42, height * 0.78)
      ..cubicTo(
        width * 0.53,
        height * 0.78,
        width * 0.58,
        height * 0.72,
        width * 0.66,
        height * 0.64,
      )
      ..lineTo(width * 0.70, height * 0.60);
    final landingArrow = Path()
      ..moveTo(width * 0.70, height * 0.36)
      ..lineTo(width * 0.70, height * 0.82)
      ..moveTo(width * 0.54, height * 0.65)
      ..lineTo(width * 0.70, height * 0.81)
      ..lineTo(width * 0.86, height * 0.65);

    canvas
      ..drawPath(upperTrack, markPaint)
      ..drawLine(
        Offset(width * 0.13, height * 0.50),
        Offset(width * 0.70, height * 0.50),
        markPaint,
      )
      ..drawPath(lowerTrack, markPaint)
      ..drawPath(landingArrow, markPaint);
  }

  @override
  bool shouldRepaint(covariant _DownpeedBrandPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
