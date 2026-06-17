import 'package:flutter/material.dart';

import '../theme.dart';

/// Gros bouton tactile (CTA principal), reprend le style web.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: const Color(0xFF04130F),
          disabledBackgroundColor: color.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
        child: Text(label),
      ),
    );
  }
}
