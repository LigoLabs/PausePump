import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Anneau circulaire de progression + temps au centre.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.fraction, // 0..1 restant
    required this.label,
    required this.isEffort,
    required this.ending,
  });

  final double fraction;
  final String label;
  final bool isEffort;
  final bool ending;

  @override
  Widget build(BuildContext context) {
    final color = ending
        ? AppColors.danger
        : (isEffort ? AppColors.effort : AppColors.accent);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final size = math.min(c.maxWidth, c.maxHeight);
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(fraction: fraction, color: color),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w800,
                    color: ending ? AppColors.danger : AppColors.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = AppColors.track;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}
