import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../theme.dart';
import 'primary_button.dart';

/// Écran « Fais ta Nᵉ série » (mode Pause seule) : cœur d'énergie qui respire.
class DoSetView extends StatefulWidget {
  const DoSetView({super.key});

  @override
  State<DoSetView> createState() => _DoSetViewState();
}

class _DoSetViewState extends State<DoSetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  String _ordinal(int n) => n == 1 ? '1re' : '${n}e';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value;
            final breathe = 1 + 0.06 * _wave(t);
            return SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++) _ring((t + i / 3) % 1.0),
                  Transform.scale(
                    scale: breathe,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [AppColors.bgElev2, AppColors.bgElev],
                        ),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.45),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppColors.accent,
                        size: 52,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          'Fais ta ${_ordinal(c.currentSeries)} série',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PrimaryButton(
            label: "J'ai fait ma série",
            onPressed: c.validateSet,
          ),
        ),
      ],
    );
  }

  double _wave(double t) => 0.5 - 0.5 * (1 - 2 * (t - 0.5).abs());

  Widget _ring(double t) {
    final scale = 0.6 + 0.58 * t;
    return Opacity(
      opacity: (1 - t).clamp(0.0, 1.0).toDouble() * 0.7,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2.5),
          ),
        ),
      ),
    );
  }
}
