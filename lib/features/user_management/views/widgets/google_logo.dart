import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Crisp vector widget rendering the official Google "G" multicolored logo.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;
    final strokeWidth = radius * 0.42;
    final innerRadius = radius - strokeWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: innerRadius);

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red arc (top): from ~210 deg to ~315 deg
    canvas.drawArc(rect, -math.pi * 0.85, math.pi * 0.55, false, paintRed);

    // Yellow arc (left): from ~135 deg to ~210 deg
    canvas.drawArc(rect, -math.pi * 1.35, math.pi * 0.50, false, paintYellow);

    // Green arc (bottom): from ~45 deg to ~135 deg
    canvas.drawArc(rect, math.pi * 0.15, math.pi * 0.50, false, paintGreen);

    // Blue arc (right): from ~315 deg to ~45 deg
    canvas.drawArc(rect, -math.pi * 0.30, math.pi * 0.45, false, paintBlue);

    // Blue horizontal center bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      center.dx - strokeWidth * 0.1,
      center.dy - strokeWidth / 2,
      innerRadius + strokeWidth / 2,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
