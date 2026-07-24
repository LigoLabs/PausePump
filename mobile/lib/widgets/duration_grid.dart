import 'package:flutter/material.dart';

import '../state/timer_controller.dart';
import '../theme.dart';

/// Grille des durées (timers enregistrés). `selected` met en valeur la durée
/// par défaut (celle que relance le raccourci). Métriques du web : 2 colonnes,
/// gap 12, cellules de ~75 de haut (padding 22 + texte 25.6), rayon 18,
/// dernière cellule pleine largeur quand le nombre est impair.
class DurationGrid extends StatelessWidget {
  const DurationGrid({
    super.key,
    required this.durations,
    required this.onPick,
    this.selected,
  });

  final List<int> durations;
  final ValueChanged<int> onPick;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < durations.length; i += 2) {
      final isLastOdd = i + 1 >= durations.length;
      rows.add(Row(
        children: [
          Expanded(child: _cell(durations[i])),
          if (!isLastOdd) ...[
            const SizedBox(width: 12),
            Expanded(child: _cell(durations[i + 1])),
          ],
        ],
      ));
      if (i + 2 < durations.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _cell(int d) {
    final isSel = d == selected;
    return GestureDetector(
      onTap: () => onPick(d),
      child: Container(
        height: 75,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? AppColors.bgElev2 : AppColors.bgElev,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSel ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          formatTime(d),
          style: TextStyle(
            fontSize: 25.6,
            fontWeight: FontWeight.w800,
            color: isSel ? AppColors.accent : AppColors.text,
          ),
        ),
      ),
    );
  }
}
