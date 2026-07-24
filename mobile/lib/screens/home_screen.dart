import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../theme.dart';
import '../widgets/mode_segment.dart';
import '../widgets/primary_button.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Bouton Options en haut à droite (48×48, comme le web)
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => showSettingsSheet(context),
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.bgElev2,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0x0DFFFFFF)),
                                ),
                                child: const Icon(Icons.settings,
                                    size: 24, color: AppColors.text),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 38.4,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              children: [
                                TextSpan(
                                    text: 'Pause',
                                    style: TextStyle(color: AppColors.text)),
                                TextSpan(
                                    text: 'Pump',
                                    style: TextStyle(color: AppColors.accent)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Gère tes pauses & efforts 💪',
                            style: TextStyle(
                                color: AppColors.textDim, fontSize: 16.8),
                          ),
                          const SizedBox(height: 22),
                          ModeSegment(value: c.mode, onChanged: c.setMode),
                          const SizedBox(height: 22),
                          const Text(
                            'Combien de séries ?',
                            style: TextStyle(
                                fontSize: 20.8, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          _seriesGrid(c),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // CTA ancré en bas de l'écran, comme le web (margin-top auto)
                  PrimaryButton(
                    label: "C'est parti",
                    onPressed: c.seriesSel < 1
                        ? null
                        : () => c.startSession(c.seriesSel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seriesGrid(TimerController c) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        for (final n in kSeriesChoices)
          GestureDetector(
            onTap: () => c.setSeriesSel(n),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.seriesSel == n ? AppColors.bgElev2 : AppColors.bgElev,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: c.seriesSel == n
                      ? AppColors.accent
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: c.seriesSel == n ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
