import 'dart:math' as math;

import 'package:flutter/material.dart';

class CentsMeter extends StatelessWidget {
  const CentsMeter({
    required this.centsOffset,
    required this.hasPitch,
    super.key,
  });

  final double centsOffset;
  final bool hasPitch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: CustomPaint(
        painter: _CentsMeterPainter(
          centsOffset: centsOffset.clamp(-50, 50),
          hasPitch: hasPitch,
          colorScheme: Theme.of(context).colorScheme,
        ),
      ),
    );
  }
}

class _CentsMeterPainter extends CustomPainter {
  const _CentsMeterPainter({
    required this.centsOffset,
    required this.hasPitch,
    required this.colorScheme,
  });

  final double centsOffset;
  final bool hasPitch;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2 - 12, size.height - 24);

    final arcPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      arcPaint,
    );

    final guidePaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 2;
    for (final mark in const [-50, -25, 0, 25, 50]) {
      final angle = math.pi + ((mark + 50) / 100) * math.pi;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 16),
        center.dy + math.sin(angle) * (radius - 16),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 2),
        center.dy + math.sin(angle) * (radius + 2),
      );
      canvas.drawLine(inner, outer, guidePaint);
    }

    final activePaint = Paint()
      ..color = hasPitch ? _needleColor() : colorScheme.outlineVariant
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final angle = math.pi + ((centsOffset + 50) / 100) * math.pi;
    final needleEnd = Offset(
      center.dx + math.cos(angle) * (radius - 26),
      center.dy + math.sin(angle) * (radius - 26),
    );
    canvas.drawLine(center, needleEnd, activePaint);
    canvas.drawCircle(center, 7, Paint()..color = activePaint.color);

    final textPainter = TextPainter(
      text: TextSpan(
        text: hasPitch ? '${centsOffset.toStringAsFixed(1)} cents' : 'No pitch',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height - 28),
    );
  }

  Color _needleColor() {
    if (centsOffset.abs() <= 5) {
      return const Color(0xFF1C8B4A);
    }
    if (centsOffset < 0) {
      return const Color(0xFF0E7490);
    }
    return const Color(0xFFB45309);
  }

  @override
  bool shouldRepaint(covariant _CentsMeterPainter oldDelegate) {
    return oldDelegate.centsOffset != centsOffset ||
        oldDelegate.hasPitch != hasPitch ||
        oldDelegate.colorScheme != colorScheme;
  }
}
