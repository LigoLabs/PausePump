import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Anneau circulaire de progression + temps au centre.
/// Proportions du web : taille `min(72vw, 300px)`, viewBox 220 avec trait 14
/// et rayon 100 (donc trait = 14/220 de la taille, rayon = 100/220), temps en
/// 3.2rem (51.2) et état « En cours / En pause » en dessous.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.fraction, // 0..1 restant
    required this.label,
    required this.stateLabel,
    required this.isEffort,
    required this.ending,
  });

  final double fraction;
  final String label;
  final String stateLabel; // « En cours » / « En pause »
  final bool isEffort;
  final bool ending;

  @override
  Widget build(BuildContext context) {
    final color = ending
        ? AppColors.danger
        : (isEffort ? AppColors.effort : AppColors.accent);
    final size = math.min(300.0, MediaQuery.sizeOf(context).width * 0.72);
    return SizedBox(
      width: size,
      height: size,
      // Le minuteur n'échantillonne le restant que toutes les 200 ms : sans
      // interpolation, l'arc sauterait 5 fois/seconde (saccadé). On glisse le
      // remplissage entre deux échantillons, rendu à la fréquence de l'écran —
      // équivalent de la transition CSS `stroke-dashoffset .25s linear` du web.
      // (begin nul ⇒ pas d'animation au 1er rendu : l'arc part à sa valeur.)
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 250),
        curve: Curves.linear,
        builder: (context, animFraction, child) => CustomPaint(
          painter: _RingPainter(fraction: animFraction, color: color, size: size),
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 51.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.1,
                  color: ending ? AppColors.danger : AppColors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stateLabel,
                style: const TextStyle(fontSize: 15.2, color: AppColors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.size});

  final double fraction;
  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    final stroke = size * 14 / 220;
    final radius = size * 100 / 220;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.track;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
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
      old.fraction != fraction || old.color != color || old.size != size;
}
