import 'dart:math' as math;

import 'package:flutter/material.dart';

class CentsMeter extends StatelessWidget {
  const CentsMeter({
    required this.centsOffset,
    required this.hasPitch,
    required this.displayLabel,
    this.height = 190,
    super.key,
  });

  final double centsOffset;
  final bool hasPitch;
  final String displayLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final targetOffset = hasPitch ? centsOffset.clamp(-50.0, 50.0) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetOffset),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      builder: (context, animatedOffset, child) {
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _CentsMeterPainter(
                    centsOffset: animatedOffset,
                    hasPitch: hasPitch,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                child: Text(displayLabel),
              ),
            ],
          ),
        );
      },
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
    final radius = math.max(
      0.0,
      math.min(size.width / 2 - 14, size.height - 26),
    );

    final arcPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.70)
      ..strokeWidth = 12
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
      ..color = colorScheme.outline.withValues(alpha: 0.70)
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
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final angle = math.pi + ((centsOffset + 50) / 100) * math.pi;
    final needleEnd = Offset(
      center.dx + math.cos(angle) * (radius - 26),
      center.dy + math.sin(angle) * (radius - 26),
    );
    canvas.drawLine(center, needleEnd, activePaint);
    canvas.drawCircle(
      center,
      10,
      Paint()..color = activePaint.color.withValues(alpha: 0.14),
    );
    canvas.drawCircle(center, 7, Paint()..color = activePaint.color);
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
