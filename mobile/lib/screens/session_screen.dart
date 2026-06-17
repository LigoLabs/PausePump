import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/timer_controller.dart';
import '../theme.dart';
import '../widgets/do_set_view.dart';
import '../widgets/duration_grid.dart';
import '../widgets/primary_button.dart';
import '../widgets/series_timeline.dart';
import '../widgets/timer_ring.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (c.step != SessionStep.done) const _TopBar(),
                if (c.step != SessionStep.done && c.step != SessionStep.setup)
                  SeriesTimeline(
                    total: c.seriesTotal,
                    dots: c.tlDots,
                    bars: c.tlBars,
                    frac: c.tlFrac,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: _StepView(step: c.step),
                  ),
                ),
              ],
            ),
            if (c.countdownValue != null) const _CountdownOverlay(),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});
  final SessionStep step;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      SessionStep.setup => const _SetupView(),
      SessionStep.duration => const _DurationView(),
      SessionStep.doSet => const DoSetView(),
      SessionStep.timer => const _TimerView(),
      SessionStep.done => const _DoneView(),
    };
  }
}

// ---------------------------------------------------------------------------
//  Barre du haut : accueil · compteur de séries · réglages
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgElev,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: c.quitToHome,
              icon: const Icon(Icons.home_outlined),
              color: AppColors.text,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const Spacer(),
            _StepBtn(icon: Icons.remove, onTap: c.seriesRemaining <= 0 ? null : c.removeSeries),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${c.seriesRemaining}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const Text('séries restantes',
                    style: TextStyle(fontSize: 11, color: AppColors.textDim)),
              ],
            ),
            _StepBtn(icon: Icons.add, onTap: c.addSeries),
            const Spacer(),
            const Icon(Icons.settings, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppColors.text,
      disabledColor: AppColors.track,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

// ---------------------------------------------------------------------------
//  Réglage Effort + Pause (enchaînement auto)
// ---------------------------------------------------------------------------
class _SetupView extends StatelessWidget {
  const _SetupView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('🔁 Enchaînement auto'),
            value: c.effortAuto,
            activeThumbColor: AppColors.accent,
            onChanged: c.setEffortAuto,
          ),
          const SizedBox(height: 8),
          const _Title("⏱️ Durée d'effort"),
          DurationGrid(selected: c.effortSel, onPick: c.setEffortSel),
          const SizedBox(height: 18),
          const _Title('😮‍💨 Durée de pause'),
          DurationGrid(selected: c.restSel, onPick: c.setRestSel),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Démarrer ▶',
            onPressed: c.effortAuto
                ? c.startEffortAuto
                : () => c.pickDuration(c.effortSel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Choix de durée
// ---------------------------------------------------------------------------
class _DurationView extends StatelessWidget {
  const _DurationView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Title(c.durationTitle),
        const SizedBox(height: 8),
        DurationGrid(
          selected: c.mode == SessionMode.pause ? c.defaultDuration() : null,
          onPick: c.pickDuration,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Décompte en cours (ring + contrôles)
// ---------------------------------------------------------------------------
class _TimerView extends StatelessWidget {
  const _TimerView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    final frac = c.durationSec > 0 ? c.remaining / c.durationSec : 0.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: TimerRing(
              fraction: frac,
              label: formatTime(c.remaining.ceil()),
              isEffort: c.phase == Phase.effort && c.mode == SessionMode.effort,
              ending: c.isEnding,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CtrlBtn(icon: Icons.refresh, label: 'Reset', onTap: c.resetPhase),
            _CtrlBtn(
              icon: c.running ? Icons.pause : Icons.play_arrow,
              label: c.running ? 'Pause' : 'Reprendre',
              main: true,
              onTap: c.togglePlayPause,
            ),
            _CtrlBtn(icon: Icons.skip_next, label: 'Suivante', onTap: c.skip),
          ],
        ),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.main = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool main;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: main ? 72 : 60,
            height: main ? 72 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: main ? AppColors.accent : AppColors.bgElev2,
            ),
            child: Icon(icon,
                color: main ? const Color(0xFF04130F) : AppColors.text,
                size: main ? 34 : 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Fin de séance
// ---------------------------------------------------------------------------
class _DoneView extends StatelessWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    final modeLabel =
        c.mode == SessionMode.effort ? 'Effort + Pause' : 'Pause seule';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            const Text('Séance terminée !',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${c.seriesTotal} série${c.seriesTotal > 1 ? 's' : ''} bouclée${c.seriesTotal > 1 ? 's' : ''} · $modeLabel 💪',
              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            PrimaryButton(label: '🔁 Recommencer', onPressed: c.restart),
            const SizedBox(height: 12),
            TextButton(
              onPressed: c.quitToHome,
              child: const Text('🏠 Retour à l\'accueil',
                  style: TextStyle(color: AppColors.textDim)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Overlay décompte « 3, 2, 1, GO »
// ---------------------------------------------------------------------------
class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay();

  @override
  Widget build(BuildContext context) {
    final v = context.select<TimerController, int?>((c) => c.countdownValue);
    if (v == null) return const SizedBox.shrink();
    final isGo = v < 0;
    return Positioned.fill(
      child: Container(
        color: AppColors.bg.withValues(alpha: 0.96),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Prépare-toi 💪',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              key: ValueKey(v),
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Text(
                isGo ? 'GO !' : '$v',
                style: TextStyle(
                  fontSize: 110,
                  fontWeight: FontWeight.w800,
                  color: isGo ? AppColors.accent : AppColors.effort,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDim,
        ),
      ),
    );
  }
}
