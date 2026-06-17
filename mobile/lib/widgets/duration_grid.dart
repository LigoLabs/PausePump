import 'package:flutter/material.dart';

import '../state/timer_controller.dart';
import '../theme.dart';

/// Grille des durées (timers enregistrés). `selected` met en valeur la durée
/// par défaut (celle que relance le raccourci).
class DurationGrid extends StatelessWidget {
  const DurationGrid({
    super.key,
    required this.onPick,
    this.selected,
    this.durations = kDurations,
  });

  final ValueChanged<int> onPick;
  final int? selected;
  final List<int> durations;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 2.4,
      ),
      itemCount: durations.length,
      itemBuilder: (context, i) {
        final d = durations[i];
        final isSel = d == selected;
        return GestureDetector(
          onTap: () => onPick(d),
          child: Container(
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
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isSel ? AppColors.accent : AppColors.text,
              ),
            ),
          ),
        );
      },
    );
  }
}
