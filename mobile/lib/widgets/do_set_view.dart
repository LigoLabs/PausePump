import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../theme.dart';
import 'primary_button.dart';

/// Écran « Fais ta Nᵉ série » (mode Pause seule) — même scène que le web :
/// halo conique qui tourne, anneaux « sonar », cœur qui respire avec l'haltère
/// (le SVG du web redessiné), titre avec un reflet qui balaie le texte.
class DoSetView extends StatefulWidget {
  const DoSetView({super.key});

  @override
  State<DoSetView> createState() => _DoSetViewState();
}

class _DoSetViewState extends State<DoSetView> with TickerProviderStateMixin {
  // Mêmes durées que les keyframes CSS.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _lift.dispose();
    _shine.dispose();
    super.dispose();
  }

  String _ordinal(int n) => n == 1 ? '1re' : '${n}e';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    final stage = math.min(230.0, MediaQuery.sizeOf(context).width * 0.58);
    final core = stage * 0.6;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: stage,
          height: stage,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulse, _spin, _lift]),
            builder: (context, _) {
              final t = _pulse.value;
              // breathe : scale 1 → 1.07 → 1 (ease-in-out)
              final breathe = 1 + 0.07 * (0.5 - 0.5 * math.cos(2 * math.pi * t));
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _glow(stage),
                  for (var i = 0; i < 3; i++) _ring(stage, (t + i / 3) % 1.0),
                  Transform.scale(
                    scale: breathe,
                    child: Container(
                      width: core,
                      height: core,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.28, -0.4), // 36% / 30%
                          colors: [AppColors.bgElev2, AppColors.bgElev],
                          stops: [0.0, 0.7],
                        ),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.45),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Center(child: _dumbbell(core)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        _shineTitle('Fais ta ${_ordinal(c.currentSeries)} série'),
        const SizedBox(height: 30),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: PrimaryButton(
            label: "J'ai fait ma série",
            onPressed: c.validateSet,
          ),
        ),
      ],
    );
  }

  /// Halo conique flouté qui tourne doucement derrière le cœur.
  Widget _glow(double stage) {
    final size = stage * 1.16; // inset -8%
    return Transform.rotate(
      angle: _spin.value * 2 * math.pi,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Colors.transparent,
                AppColors.accent.withValues(alpha: 0.45),
                Colors.transparent,
                AppColors.effort.withValues(alpha: 0.38),
                Colors.transparent,
                AppColors.accent.withValues(alpha: 0.45),
              ],
              stops: const [0.0, 0.18, 0.38, 0.60, 0.82, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Anneau d'énergie qui s'étend vers l'extérieur (opacité .85 → 0).
  Widget _ring(double stage, double t) {
    final scale = 0.6 + 0.58 * t;
    return Opacity(
      opacity: (1 - t).clamp(0.0, 1.0) * 0.85,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: stage,
          height: stage,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 3 - 2 * t),
          ),
        ),
      ),
    );
  }

  /// Haltère du web (SVG 64×64 : barre + 4 disques) qui « soulève ».
  Widget _dumbbell(double core) {
    final t = _lift.value;
    final wave = 0.5 - 0.5 * math.cos(2 * math.pi * t); // 0 → 1 → 0
    final size = core * 0.5;
    return Transform.translate(
      offset: Offset(0, (4 - 10 * wave) * size / 64 * 4),
      child: Transform.rotate(
        angle: (-5 + 10 * wave) * math.pi / 180,
        child: CustomPaint(
          size: Size.square(size),
          painter: _DumbbellPainter(),
        ),
      ),
    );
  }

  /// Titre avec un reflet qui balaie le texte (équivalent du gradient animé).
  Widget _shineTitle(String text) {
    return AnimatedBuilder(
      animation: _shine,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final dx = (1 - 2 * _shine.value) * bounds.width * 2.2;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [AppColors.text, AppColors.accent, AppColors.text],
              stops: const [0.32, 0.5, 0.68],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 28.8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Les 5 traits du SVG web (viewBox 64, trait 5, bouts ronds).
class _DumbbellPainter extends CustomPainter {
  static const _lines = [
    [22.0, 32.0, 42.0, 32.0], // barre
    [13.0, 23.0, 13.0, 41.0], // petit disque gauche
    [22.0, 17.0, 22.0, 47.0], // grand disque gauche
    [42.0, 17.0, 42.0, 47.0], // grand disque droit
    [51.0, 23.0, 51.0, 41.0], // petit disque droit
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 64;
    // Ombre portée douce (drop-shadow du web) puis le trait net.
    final shadow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.45)
      ..strokeWidth = 5 * k
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final stroke = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 5 * k
      ..strokeCap = StrokeCap.round;
    for (final paint in [shadow, stroke]) {
      final dy = paint == shadow ? 4 * k : 0.0;
      for (final l in _lines) {
        canvas.drawLine(
          Offset(l[0] * k, l[1] * k + dy),
          Offset(l[2] * k, l[3] * k + dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DumbbellPainter old) => false;
}
