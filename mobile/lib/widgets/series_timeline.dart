import 'package:flutter/material.dart';

import '../theme.dart';

/// Timeline des séries : ronds reliés. Le rond se remplit quand la série est
/// validée, la barre se remplit au rythme du timer de pause.
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

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final restActive = bars < dots; // une pause est en cours
    final children = <Widget>[];
    for (var i = 0; i < total; i++) {
      if (i > 0) {
        final double fill = i - 1 < bars
            ? 1.0
            : (i - 1 == bars && restActive ? frac.clamp(0.0, 1.0).toDouble() : 0.0);
        children.add(Expanded(child: _Bar(fill: fill)));
      }
      children.add(_Dot(done: i < dots, current: i == dots));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(children: children),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.current});
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: current ? 19 : 15,
      height: current ? 19 : 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.accent
            : (current ? AppColors.bgElev2 : AppColors.track),
        border: Border.all(
          color: (done || current) ? AppColors.accent : AppColors.track,
          width: 2,
        ),
        boxShadow: current
            ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 8, spreadRadius: 2)]
            : null,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fill});
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      constraints: const BoxConstraints(maxWidth: 46),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(2),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: c.maxWidth * fill.clamp(0.0, 1.0),
            height: c.maxHeight,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }
}
