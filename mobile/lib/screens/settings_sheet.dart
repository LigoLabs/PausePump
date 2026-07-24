import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/enums.dart';
import '../state/timer_controller.dart';
import '../theme.dart';

/// Version affichée dans le pied de la modale (à garder alignée avec
/// `version:` de pubspec.yaml — pas de plugin natif pour rester léger).
const String kAppVersion = '1.0.0';

/// Ouvre la modale Options — l'équivalent de la modale web (3 onglets :
/// Général / Son / Timers + pied de page avec la version).
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgElev,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    final s = c.settings;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return Padding(
      // Laisse la place au clavier (éditeur de timers).
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- En-tête ----
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Options',
                        style: TextStyle(
                            fontSize: 22.4, fontWeight: FontWeight.w700)),
                    _IconBtn(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // ---- Onglets ----
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _tabBtn('⚙️ Général', 0),
                    const SizedBox(width: 6),
                    _tabBtn('🔊 Son', 1),
                    const SizedBox(width: 6),
                    _tabBtn('⏱️ Timers', 2),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ---- Contenu ----
              Flexible(
                child: SingleChildScrollView(
                  child: switch (_tab) {
                    0 => _GeneralTab(c: c, s: s),
                    1 => _SoundTab(c: c, s: s),
                    _ => _TimersTab(c: c, s: s),
                  },
                ),
              ),
              // ---- Pied : version ----
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 2),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x0DFFFFFF)),
                  ),
                ),
                child: const Row(
                  children: [
                    Text(
                      'PausePump · version $kAppVersion',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.bgElev2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.7,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.text : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Onglet Général
// ---------------------------------------------------------------------------
class _GeneralTab extends StatelessWidget {
  const _GeneralTab({required this.c, required this.s});
  final TimerController c;
  final AppSettings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OptRow(
          label: "🔆 Garder l'écran allumé",
          value: s.keepAwake,
          onChanged: (v) => c.updateSettings(s.copyWith(keepAwake: v)),
        ),
        _OptRow(
          label: "🏁 Décompte avant l'effort",
          value: s.prepCountdown,
          onChanged: (v) => c.updateSettings(s.copyWith(prepCountdown: v)),
        ),
        const _Hint(
            'Affiche un décompte « 3, 2, 1 » pour te préparer avant chaque '
            'effort, en mode Effort + Pause à chaque étape (sans enchaînement auto).'),
        _OptRow(
          label: '🏋️ Écran « Fais ta série »',
          value: s.doSetScreen,
          onChanged: (v) => c.updateSettings(s.copyWith(doSetScreen: v)),
        ),
        const _Hint(
            'En mode Pause seule, affiche un écran « Fais ta série » avant '
            'chaque pause. Décoche pour aller directement à la pause.'),
        _OptRow(
          label: '🎉 Écran de fin de séance',
          value: s.endScreen,
          onChanged: (v) => c.updateSettings(s.copyWith(endScreen: v)),
        ),
        const _Hint(
            'Affiche un écran récap quand toutes les séries sont faites. '
            'Décoche pour revenir directement à l\'accueil.'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Onglet Son
// ---------------------------------------------------------------------------
class _SoundTab extends StatelessWidget {
  const _SoundTab({required this.c, required this.s});
  final TimerController c;
  final AppSettings s;

  @override
  Widget build(BuildContext context) {
    final volPct = (s.volume * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OptRow(
          label: '📳 Vibrer à la fin',
          value: s.vibrate,
          onChanged: (v) {
            c.updateSettings(s.copyWith(vibrate: v));
            if (v) HapticFeedback.mediumImpact();
          },
        ),
        _OptRow(
          label: '🔊 Jouer un son à la fin',
          value: s.sound,
          onChanged: (v) => c.updateSettings(s.copyWith(sound: v)),
        ),
        // ---- Volume ----
        const _BlockSep(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🔉 Volume', style: TextStyle(fontSize: 16.3)),
              Text('$volPct%',
                  style: const TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.track,
            thumbColor: AppColors.accent,
            overlayColor: const Color(0x2222D3A7),
            trackHeight: 6,
          ),
          child: Slider(
            value: volPct.toDouble(),
            min: 0,
            max: 100,
            divisions: 20, // pas de 5, comme le web
            onChanged: (v) =>
                c.updateSettings(s.copyWith(volume: v.round() / 100)),
          ),
        ),
        const _Hint('Règle le volume de tous les bips de l\'app.'),
        // ---- Choix du son ----
        const _BlockSep(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('🎵 Son du bip', style: TextStyle(fontSize: 16.3)),
              _MiniBtn(
                label: '▶ Écouter',
                onTap: () => c.audio.previewAlarm(s.alarm, s.volume),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.bgElev2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AlarmSound>(
              value: s.alarm,
              isExpanded: true,
              dropdownColor: AppColors.bgElev2,
              style: const TextStyle(fontSize: 16, color: AppColors.text),
              items: [
                for (final a in AlarmSound.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (a) {
                if (a == null) return;
                c.updateSettings(s.copyWith(alarm: a));
                c.audio.previewAlarm(a, s.volume);
              },
            ),
          ),
        ),
        const _BlockSep(),
        _OptRow(
          label: '🔔 Notification du temps',
          value: s.notify,
          onChanged: (v) => c.updateSettings(s.copyWith(notify: v)),
        ),
        const _Hint(
            'Prévient quand le temps est écoulé, même si l\'app est en '
            'arrière-plan ou l\'écran verrouillé.'),
        _OptRow(
          label: '🔊 Son à la notification',
          value: s.notifySound,
          onChanged: (v) => c.updateSettings(s.copyWith(notifySound: v)),
        ),
        const _Hint(
            'La notification de fin joue le son du bip choisi (ou la sonnerie '
            'du téléphone si « Jouer un son à la fin » est coupé). Décoche '
            'pour une notification silencieuse.'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
//  Onglet Timers (éditeur des durées)
// ---------------------------------------------------------------------------
class _TimersTab extends StatelessWidget {
  const _TimersTab({required this.c, required this.s});
  final TimerController c;
  final AppSettings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint(
            'Tes durées enregistrées (effort & pause). Modifie, ajoute ou supprime.'),
        for (var i = 0; i < s.timers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TimerRow(
              // Clé stable par position + valeur : l'état de saisie est remis
              // à zéro quand la liste change (ajout/suppression/reset).
              key: ValueKey('timer-$i-${s.timers[i]}'),
              seconds: s.timers[i],
              onCommit: (secs) {
                final next = [...s.timers];
                next[i] = secs;
                c.updateSettings(s.copyWith(timers: next));
              },
              onDelete: () {
                if (s.timers.length <= 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _snack('Garde au moins un timer'),
                  );
                  return;
                }
                final next = [...s.timers]..removeAt(i);
                c.updateSettings(s.copyWith(timers: next));
              },
            ),
          ),
        _MiniBtn(
          label: '＋ Ajouter un timer',
          wide: true,
          onTap: () =>
              c.updateSettings(s.copyWith(timers: [...s.timers, 60])),
        ),
        Center(
          child: TextButton(
            onPressed: () =>
                c.updateSettings(s.copyWith(timers: kDefaultTimers)),
            child: const Text(
              'Réinitialiser par défaut',
              style: TextStyle(
                fontSize: 13.8,
                color: AppColors.textDim,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textDim,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

SnackBar _snack(String msg) => SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Color(0xFF04130F), fontWeight: FontWeight.w700)),
      backgroundColor: AppColors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

/// Une ligne de l'éditeur : champs min : sec + suppression.
class _TimerRow extends StatefulWidget {
  const _TimerRow({
    super.key,
    required this.seconds,
    required this.onCommit,
    required this.onDelete,
  });

  final int seconds;
  final ValueChanged<int> onCommit;
  final VoidCallback onDelete;

  @override
  State<_TimerRow> createState() => _TimerRowState();
}

class _TimerRowState extends State<_TimerRow> {
  late final TextEditingController _min =
      TextEditingController(text: '${widget.seconds ~/ 60}');
  late final TextEditingController _sec = TextEditingController(
      text: (widget.seconds % 60).toString().padLeft(2, '0'));

  @override
  void dispose() {
    _min.dispose();
    _sec.dispose();
    super.dispose();
  }

  void _commit() {
    final m = (int.tryParse(_min.text) ?? 0).clamp(0, 99);
    final s = (int.tryParse(_sec.text) ?? 0).clamp(0, 59);
    var total = m * 60 + s;
    if (total < 5) total = 5; // minimum 5 s, comme le web
    _min.text = '${total ~/ 60}';
    _sec.text = (total % 60).toString().padLeft(2, '0');
    if (total != widget.seconds) widget.onCommit(total);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgElev2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _numField(_min),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(':',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDim)),
          ),
          _numField(_sec),
          const Spacer(),
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl) {
    return SizedBox(
      width: 58,
      child: Focus(
        onFocusChange: (has) {
          if (!has) _commit();
        },
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          onEditingComplete: () {
            _commit();
            FocusScope.of(context).unfocus();
          },
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            filled: true,
            fillColor: AppColors.bg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.track),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Petits widgets partagés (rangée à interrupteur, hint, boutons)
// ---------------------------------------------------------------------------
class _OptRow extends StatelessWidget {
  const _OptRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 16.3)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.accent,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.track,
            inactiveThumbColor: Colors.white,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 13.1, color: AppColors.textDim, height: 1.4),
      ),
    );
  }
}

class _BlockSep extends StatelessWidget {
  const _BlockSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 1,
      color: const Color(0x12FFFFFF),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.label, required this.onTap, this.wide = false});

  final String label;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: wide
            ? const EdgeInsets.symmetric(vertical: 14)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        alignment: wide ? Alignment.center : null,
        decoration: BoxDecoration(
          color: AppColors.bgElev2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.4,
            fontWeight: FontWeight.w700,
            color: wide ? AppColors.text : AppColors.accent,
          ),
        ),
      ),
    );
    return wide
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(width: double.infinity, child: btn),
          )
        : btn;
  }
}

/// Bouton icône 48×48 (fond bgElev2, rayon 14) — style des boutons du web.
class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

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
        child: Icon(icon, color: AppColors.text, size: 24),
      ),
    );
  }
}
