import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/timer_controller.dart';
import '../theme.dart';
import '../widgets/do_set_view.dart';
import '../widgets/duration_grid.dart';
import '../widgets/primary_button.dart';
import '../widgets/series_timeline.dart';
import '../widgets/timer_ring.dart';
import 'settings_sheet.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Action « la suite », comme le web : valider la série, relancer la dernière
  /// durée mémorisée, ou recommencer la séance. Déclenchée par la touche Espace
  /// (clavier / clicker Bluetooth) et par le double tap sur l'écran.
  bool _quickAdvance() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    final c = context.read<TimerController>();
    if (c.countdownValue != null) return false; // décompte « 3, 2, 1 » en cours
    switch (c.step) {
      case SessionStep.doSet:
        c.validateSet();
        return true;
      case SessionStep.duration:
        c.quickLaunchDefault();
        return true;
      case SessionStep.done:
        c.restart();
        return true;
      default:
        return false;
    }
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.space) {
      return false;
    }
    return _quickAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Double tap n'importe où sur le fond = équivalent tactile de la
            // touche Espace. Volontairement placé SOUS le contenu : le Stack
            // teste ses enfants du haut vers le bas, donc les boutons captent
            // le tap avant nous — sinon leur simple tap serait retardé de
            // ~300 ms le temps que l'arène des gestes tranche.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _quickAdvance,
                child: const SizedBox.expand(),
              ),
            ),
            Column(
              children: [
                // La barre du haut et la timeline restent visibles partout,
                // sauf sur l'écran de fin (rendu plein écran, comme le web).
                if (c.step != SessionStep.done) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _TopBar(),
                  ),
                  SeriesTimeline(
                    total: c.seriesTotal,
                    dots: c.tlDots,
                    bars: c.tlBars,
                    frac: c.tlFrac,
                  ),
                ],
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElev,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SquareBtn(
            onTap: c.quitToHome,
            child: const Icon(Icons.home_outlined, size: 26, color: AppColors.text),
          ),
          // Compteur : − / readout / + (le readout se comprime au besoin)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SquareBtn(
                  onTap: c.seriesRemaining <= 0 ? null : c.removeSeries,
                  child: Icon(Icons.remove,
                      size: 26,
                      color: c.seriesRemaining <= 0
                          ? AppColors.track
                          : AppColors.text),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 96),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${c.seriesRemaining}',
                          style: const TextStyle(
                            fontSize: 30.4,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text('séries restantes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                ),
                _SquareBtn(
                  onTap: c.addSeries,
                  child: const Icon(Icons.add, size: 26, color: AppColors.text),
                ),
              ],
            ),
          ),
          _SquareBtn(
            onTap: () => showSettingsSheet(context),
            child: const Icon(Icons.settings, size: 24, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

/// Bouton carré 48×48 (fond bgElev2, rayon 14) — style icon-btn/step-btn web.
class _SquareBtn extends StatelessWidget {
  const _SquareBtn({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bgElev2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Réglage Effort + Pause (enchaînement auto ou étape par étape)
// ---------------------------------------------------------------------------
class _SetupView extends StatelessWidget {
  const _SetupView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              // Toggle auto/manuel (carte bgElev, comme le web)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgElev,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🔁 Enchaînement auto',
                        style: TextStyle(fontSize: 16.3)),
                    Switch(
                      value: c.effortAuto,
                      onChanged: c.setEffortAuto,
                      activeTrackColor: AppColors.accent,
                      activeThumbColor: Colors.white,
                      inactiveTrackColor: AppColors.track,
                      inactiveThumbColor: Colors.white,
                      trackOutlineColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                c.effortAuto
                    ? "Tu règles l'effort & la pause, puis ça enchaîne tout seul en continu."
                    : "Tu choisiras la durée à chaque étape : d'abord l'effort, puis la pause.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.1, color: AppColors.textDim, height: 1.4),
              ),
              // Les grilles ne servent qu'en enchaînement auto (comme le web).
              if (c.effortAuto) ...[
                const SizedBox(height: 8),
                const _Title("⏱️ Durée d'effort"),
                DurationGrid(
                  durations: c.timers,
                  selected: c.effortSel,
                  onPick: c.setEffortSel,
                ),
                const SizedBox(height: 22),
                const _Title('😮‍💨 Durée de pause'),
                DurationGrid(
                  durations: c.timers,
                  selected: c.restSel,
                  onPick: c.setRestSel,
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Démarrer ▶',
                // Étape par étape : on passe par le choix de la durée d'effort
                // (pickDuration directement viserait la mauvaise phase).
                onPressed: c.effortAuto ? c.startEffortAuto : c.startEffortManual,
              ),
            ],
          ),
        ),
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
    return SingleChildScrollView(
      // deferToChild : les zones vides laissent passer le tap jusqu'au
      // détecteur de double tap posé au fond de l'écran.
      hitTestBehavior: HitTestBehavior.deferToChild,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              _Title(c.durationTitle),
              DurationGrid(
                durations: c.timers,
                // La durée par défaut est surlignée dans tous les modes
                // (c'est elle que relance le raccourci), comme le web.
                selected: c.defaultDuration(),
                onPick: c.pickDuration,
              ),
              // Indice équivalent au « Espace relancer 1:30 » du web.
              if (c.defaultDuration() > 0) Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Double tap pour relancer ${formatTime(c.defaultDuration())}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13.1, color: AppColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Décompte en cours (badge de phase + ring + contrôles)
// ---------------------------------------------------------------------------
class _TimerView extends StatelessWidget {
  const _TimerView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    final frac = c.durationSec > 0 ? c.remaining / c.durationSec : 0.0;
    final isEffort = c.phase == Phase.effort && c.mode == SessionMode.effort;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PhaseBadge(isEffort: isEffort, pauseOnly: c.mode == SessionMode.pause),
        const SizedBox(height: 18),
        TimerRing(
          fraction: frac,
          label: formatTime(c.remaining.ceil()),
          stateLabel: c.running ? 'En cours' : 'En pause',
          isEffort: isEffort,
          ending: c.isEnding,
        ),
        const SizedBox(height: 34),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Row(
            children: [
              _CtrlBtn(icon: Icons.refresh, label: 'Reset', onTap: c.resetPhase),
              const SizedBox(width: 10),
              _CtrlBtn(
                icon: c.running ? Icons.pause : Icons.play_arrow,
                label: c.running ? 'Pause' : 'Reprendre',
                main: true,
                onTap: c.togglePlayPause,
              ),
              const SizedBox(width: 10),
              _CtrlBtn(icon: Icons.skip_next, label: 'Suivante', onTap: c.skip),
              const SizedBox(width: 10),
              _CtrlBtn(icon: Icons.replay, label: 'Durée', onTap: c.backToChoice),
            ],
          ),
        ),
      ],
    );
  }
}

/// Badge « Pause » / « 💪 Effort » au-dessus de l'anneau (comme le web).
class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.isEffort, required this.pauseOnly});
  final bool isEffort;
  final bool pauseOnly;

  @override
  Widget build(BuildContext context) {
    final text = pauseOnly ? 'Pause' : (isEffort ? '💪 Effort' : '😮‍💨 Pause');
    final color = isEffort ? AppColors.effort : AppColors.accent;
    final bg = isEffort ? const Color(0x24F59E0B) : const Color(0x1F22D3A7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

/// Bouton de contrôle façon web : rectangle arrondi, icône + libellé.
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: main ? AppColors.bgElev2 : AppColors.bgElev,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: AppColors.text),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.2, color: AppColors.textDim)),
            ],
          ),
        ),
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
    final emojiSize =
        (MediaQuery.sizeOf(context).width * 0.30).clamp(80.0, 128.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: TextStyle(fontSize: emojiSize, height: 1)),
            const SizedBox(height: 16),
            const Text('Séance terminée !',
                style: TextStyle(fontSize: 30.4, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '${c.seriesTotal} série${c.seriesTotal > 1 ? 's' : ''} bouclée${c.seriesTotal > 1 ? 's' : ''} · $modeLabel 💪',
              style: const TextStyle(color: AppColors.textDim, fontSize: 16.8),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  PrimaryButton(label: '🔁 Recommencer', onPressed: c.restart),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: c.quitToHome,
                    child: const Text('🏠 Retour à l\'accueil',
                        style: TextStyle(
                            fontSize: 13.8, color: AppColors.textDim)),
                  ),
                ],
              ),
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
    final c = context.watch<TimerController>();
    final v = c.countdownValue;
    if (v == null) return const SizedBox.shrink();
    final isGo = v < 0;
    final numSize =
        (MediaQuery.sizeOf(context).width * 0.38).clamp(88.0, 144.0);
    final glow = isGo ? AppColors.accent : AppColors.effort;
    return Positioned.fill(
      // Tap n'importe où → on démarre tout de suite (comme le web).
      child: GestureDetector(
        onTap: c.skipCountdown,
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            // Halo ambré au centre sur fond quasi opaque (gradient du web).
            gradient: RadialGradient(
              center: Alignment(0, -0.16),
              radius: 0.9,
              colors: [Color(0x29F59E0B), Color(0xF70F1219)],
              stops: [0.0, 0.62],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Prépare-toi 💪',
                  style: TextStyle(
                      fontSize: 21.6,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
              const SizedBox(height: 12),
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
                    fontSize: numSize,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: isGo ? AppColors.accent : AppColors.effort,
                    shadows: [
                      Shadow(
                        color: glow.withValues(alpha: isGo ? 0.55 : 0.45),
                        blurRadius: isGo ? 50 : 44,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text("L'effort démarre…",
                  style:
                      TextStyle(fontSize: 16.3, color: AppColors.textDim)),
            ],
          ),
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
      padding: const EdgeInsets.only(top: 8, bottom: 16),
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
