import 'package:flutter/material.dart';

import '../theme.dart';

/// Timeline des séries : ronds reliés. Le rond se remplit quand la série est
/// validée, la barre se remplit au rythme du timer de pause.
/// Métriques du web : points 15px (courant ×1.32 + halo net de 4px), barres de
/// 3px de haut larges de 10 à 46px, l'ensemble centré.
class SeriesTimeline extends StatelessWidget {
  const SeriesTimeline({
    super.key,
    required this.total,
    required this.dots,
    required this.bars,
    required this.frac,
  });

  final int total;
  final int dots; // points pleins
  final int bars; // barres pleines
  final double frac; // remplissage de la barre en cours

  static const _dotSize = 15.0;
  static const _currentScale = 1.32;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final restActive = bars < dots; // une pause est en cours
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      child: SizedBox(
        // De l'air pour le halo / l'agrandissement du rond en cours.
        height: _dotSize * _currentScale + 10,
        child: LayoutBuilder(
          builder: (context, c) {
            final barW = total > 1
                ? ((c.maxWidth - total * _dotSize) / (total - 1))
                    .clamp(10.0, 46.0)
                : 0.0;
            final children = <Widget>[];
            for (var i = 0; i < total; i++) {
              if (i > 0) {
                final double fill = i - 1 < bars
                    ? 1.0
                    : (i - 1 == bars && restActive
                        ? frac.clamp(0.0, 1.0).toDouble()
                        : 0.0);
                children.add(_Bar(fill: fill, width: barW));
              }
              children.add(_Dot(done: i < dots, current: i == dots));
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.current});
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final size = current
        ? SeriesTimeline._dotSize * SeriesTimeline._currentScale
        : SeriesTimeline._dotSize;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.accent
            : (current ? AppColors.bgElev : AppColors.track),
        border: Border.all(
          color: (done || current) ? AppColors.accent : AppColors.track,
          width: 2,
        ),
        // Halo net (pas de flou) autour du rond en cours, comme le web.
        boxShadow: current
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fill, required this.width});
  final double fill;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: width * fill.clamp(0.0, 1.0),
          height: 3,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
