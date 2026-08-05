import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/segmented_control.dart';

/// Theme + accent color personalization, reached from the Profile tab.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final modeIndex = switch (app.themeMode) { ThemeMode.light => 0, ThemeMode.dark => 1, ThemeMode.system => 2 };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Text('Personnalisation', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: _card(
                  title: 'Apparence',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedControl(
                        labels: const ['Clair', 'Sombre', 'Auto'],
                        selectedIndex: modeIndex,
                        onChanged: (i) => app.setThemeMode(switch (i) { 0 => ThemeMode.light, 1 => ThemeMode.dark, _ => ThemeMode.system }),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        app.themeMode == ThemeMode.system ? 'Suit le réglage clair/sombre de votre appareil.' : 'Thème fixe, quel que soit le réglage de votre appareil.',
                        style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _card(
                  title: 'Couleur d’accent',
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final preset in AccentPreset.values) _AccentSwatchButton(preset: preset, selected: app.accentPreset == preset, onTap: () => app.setAccentPreset(preset)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: AppColors.mut, letterSpacing: 0.5)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AccentSwatchButton extends StatelessWidget {
  final AccentPreset preset;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatchButton({required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = accentPreviewColor(preset);

    return Pressable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected ? Border.all(color: AppColors.ink, width: 3) : null,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(height: 6),
          Text(accentPresetLabel(preset), style: bodyFont(size: 11, weight: FontWeight.w700, color: AppColors.mut)),
        ],
      ),
    );
  }
}
