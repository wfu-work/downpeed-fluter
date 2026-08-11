import 'package:flutter/material.dart';

import '../../configs/theme/downpeed_theme_tokens.dart';

class DownpeedBrandMark extends StatelessWidget {
  const DownpeedBrandMark({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Downpeed',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DownpeedBrandPainter(color ?? context.downpeedColors.text),
        ),
      ),
    );
  }
}

class _DownpeedBrandPainter extends CustomPainter {
  const _DownpeedBrandPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final markPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.068
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final portal = Path()
      ..moveTo(width * 0.304, height * 0.266)
      ..lineTo(width * 0.458, height * 0.266)
      ..cubicTo(
        width * 0.65,
        height * 0.266,
        width * 0.756,
        height * 0.356,
        width * 0.756,
        height * 0.512,
      )
      ..cubicTo(
        width * 0.756,
        height * 0.668,
        width * 0.65,
        height * 0.758,
        width * 0.458,
        height * 0.758,
      )
      ..lineTo(width * 0.304, height * 0.758)
      ..close();
    final arrow = Path()
      ..moveTo(width * 0.53, height * 0.37)
      ..lineTo(width * 0.53, height * 0.63)
      ..moveTo(width * 0.43, height * 0.548)
      ..lineTo(width * 0.53, height * 0.648)
      ..lineTo(width * 0.63, height * 0.548);

    canvas
      ..drawPath(portal, markPaint)
      ..drawPath(arrow, markPaint);
  }

  @override
  bool shouldRepaint(covariant _DownpeedBrandPainter oldDelegate) =>
      oldDelegate.color != color;
}
