import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/timer_controller.dart';
import '../theme.dart';
import '../widgets/mode_segment.dart';
import '../widgets/primary_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _series = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TimerController>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.settings, color: AppColors.text),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(text: 'Pause', style: TextStyle(color: AppColors.text)),
                        TextSpan(text: 'Pump', style: TextStyle(color: AppColors.accent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gère tes pauses & efforts 💪',
                    style: TextStyle(color: AppColors.textDim, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ModeSegment(value: c.mode, onChanged: c.setMode),
                  const SizedBox(height: 22),
                  const Text(
                    'Combien de séries ?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  _seriesGrid(),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: "C'est parti",
                    onPressed: _series < 1 ? null : () => c.startSession(_series),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seriesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.1,
      children: [
        for (final n in kSeriesChoices)
          GestureDetector(
            onTap: () => setState(() => _series = n),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _series == n ? AppColors.bgElev2 : AppColors.bgElev,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _series == n ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _series == n ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
