import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme.dart';

/// Sélecteur de mode (Pause seule / Effort + Pause).
class ModeSegment extends StatelessWidget {
  const ModeSegment({super.key, required this.value, required this.onChanged});

  final SessionMode value;
  final ValueChanged<SessionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _seg('Pause seule', SessionMode.pause),
          const SizedBox(width: 6),
          _seg('Effort + Pause', SessionMode.effort),
        ],
      ),
    );
  }

  Widget _seg(String label, SessionMode m) {
    final selected = value == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.bgElev2 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.text : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}
