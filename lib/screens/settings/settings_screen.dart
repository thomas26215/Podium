import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../logic/plus.dart';
import '../../models/plus_membership.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/backdrop.dart';
import '../../widgets/appearance_preview.dart';
import '../../widgets/common.dart';
import '../../widgets/option_chip.dart';
import '../../widgets/plus_mark.dart';
import '../../widgets/segmented_control.dart';
import '../shop/shop_item_view.dart';
import '../shop/shop_screen.dart';
import '../shop/unlock_sheet.dart';

const _tabs = <({String label, IconData icon})>[
  (label: 'Thèmes', icon: Icons.auto_awesome_rounded),
  (label: 'Couleurs', icon: Icons.palette_outlined),
  (label: 'Effets', icon: Icons.layers_outlined),
  (label: 'Fond', icon: Icons.wallpaper_rounded),
  (label: 'Texte', icon: Icons.text_fields_rounded),
  (label: 'Réglages', icon: Icons.tune_rounded),
];

/// Appearance & settings, reached from the Profile screen: ready-made
/// themes, then every piece of the look on its own — colours, surface
/// effects, backdrop, fonts, corners — with a live miniature of the app
/// pinned on top, and the app's other settings. Every change applies at
/// once, everywhere (see AppearanceScope) — but for the Podium+ ones
/// (marked with a +), which a non-member first sees on the Podium+ page.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final previewHeight = math.min(150.0, MediaQuery.sizeOf(context).height * 0.2);
    final content = switch (_tab) {
      0 => _ThemesTab(app: app),
      1 => _ColorsTab(app: app),
      2 => _EffectsTab(app: app),
      3 => _BackdropTab(app: app),
      4 => _TextTab(app: app),
      _ => _SettingsTab(app: app),
    };

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.ink),
        title: Text('Apparence & réglages', style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: FadeSlideIn(
                child: SizedBox(
                  height: previewHeight,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: AppearancePreview.designSize.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: AppearancePreview(tokens: AppColors.tokens, replayOnStyleChange: true),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  for (final (i, t) in _tabs.indexed) ...[
                    OptionChip(label: t.label, icon: t.icon, selected: i == _tab, onTap: () => setState(() => _tab = i)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: appStepTransition,
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                    child: KeyedSubtree(key: ValueKey(_tab), child: content),
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

/// Applies a pick — at once when the player has it (free, bought, or with
/// Podium++); otherwise once it's unlocked, with the Boutique's sheet for
/// the theme's [pack] or the one [item], which shows [look] off — in dark
/// mode when [dark].
Future<void> _pick(
  BuildContext context,
  AppState app, {
  required bool locked,
  ShopPack? pack,
  ShopItem? item,
  required String title,
  String? why,
  required Appearance look,
  bool? dark,
  required VoidCallback apply,
}) async {
  if (!locked) {
    apply();
    return;
  }
  final d = dark ?? app.isDark;
  final outcome = await showUnlockSheet(
    context,
    items: [?item],
    pack: pack,
    title: title,
    message: why,
    preview: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: AspectRatio(
          aspectRatio: AppearancePreview.designSize.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: FittedBox(fit: BoxFit.cover, child: SizedBox.fromSize(size: AppearancePreview.designSize, child: AppearancePreview(tokens: AppTokens.resolve(look, dark: d)))),
          ),
        ),
      ),
    ),
    plusPreviewLook: look,
    plusPreviewDark: d,
  );
  if (outcome == UnlockOutcome.unlocked) apply();
}

/// [_pick] for one [part] of the look, sold on its own.
Future<void> _pickPart(BuildContext context, AppState app, Object part, {required Appearance look, required VoidCallback apply}) {
  final item = partItem(part);
  return _pick(context, app, locked: !partUnlocked(part, app.unlocks), item: item, title: shopItemLabel(item), why: item.kind.label, look: look, apply: apply);
}

// ============================== tabs ==============================

class _ThemesTab extends StatelessWidget {
  final AppState app;
  const _ThemesTab({required this.app});

  /// A random look — one roll of the dice per setting, among what the
  /// player has unlocked.
  Appearance _roll(math.Random r) {
    T pick<T extends Object>(Iterable<T> values) {
      final list = values.where((v) => partUnlocked(v, app.unlocks)).toList();
      return list[r.nextInt(list.length)];
    }

    return app.appearance.copyWith(
      palette: pick(PaletteId.values),
      accent: pick(AccentId.values.where((a) => a != AccentId.custom)),
      surface: pick(SurfaceStyle.values),
      corners: pick(CornerStyle.values),
      font: pick(FontPair.values.where((f) => f != FontPair.system)),
      backdrop: pick(BackdropStyle.values),
      navBar: pick(NavBarStyle.values),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = presetMatching(app.appearance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                current == null ? 'Votre thème est personnalisé. Choisissez-en un pour tout régler d’un coup.' : 'Un thème règle d’un coup couleurs, effets, police et fond — vous pourrez ensuite tout ajuster.',
                style: bodyFont(size: 12.5, weight: FontWeight.w600, color: AppColors.mut, height: 1.35),
              ),
            ),
            const SizedBox(width: 12),
            OptionChip(
              label: 'Au hasard',
              icon: Icons.casino_rounded,
              selected: false,
              onTap: () {
                HapticFeedback.mediumImpact();
                app.setAppearance(_roll(math.Random()));
              },
            ),
          ],
        ),
        if (app.plusTier != PlusTier.plusPlus) ...[
          const SizedBox(height: 14),
          PlusHint(
            text: 'Ce qui est marqué ++ s’achète à l’unité dans la Boutique, ou vient tout entier avec Podium++.',
            action: 'Boutique',
            tier: PlusTier.plusPlus,
            onTap: () => ShopScreen.open(context, interface: true),
          ),
        ],
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [
            for (final (i, p) in kAppearancePresets.indexed)
              FadeSlideIn(
                delay: staggerDelay(i, stepMs: 35),
                child: _PresetTile(preset: p, selected: identical(current, p), app: app),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorsTab extends StatelessWidget {
  final AppState app;
  const _ColorsTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final modeIndex = switch (app.themeMode) { ThemeMode.light => 0, ThemeMode.dark => 1, ThemeMode.system => 2 };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: staggered([
        _Section(
          title: 'Mode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedControl(
                labels: const ['Clair', 'Sombre', 'Auto'],
                selectedIndex: modeIndex,
                onChanged: (i) => app.setThemeMode(switch (i) { 0 => ThemeMode.light, 1 => ThemeMode.dark, _ => ThemeMode.system }),
              ),
              const SizedBox(height: 10),
              _Hint(app.themeMode == ThemeMode.system ? 'Suit le réglage clair/sombre de votre appareil.' : 'Thème fixe, quel que soit le réglage de votre appareil.'),
            ],
          ),
        ),
        _Section(
          title: 'Ambiance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final p in PaletteId.values) _PaletteSwatch(palette: p, app: app),
                ],
              ),
              const SizedBox(height: 12),
              const _Hint('Les tons du fond, des cartes et du texte. « Teinté » suit votre couleur d’accent.'),
            ],
          ),
        ),
        _Section(
          title: 'Couleur d’accent',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 14,
                children: [
                  for (final accent in AccentId.values) _AccentSwatch(accent: accent, app: app),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: a.accent != AccentId.custom
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _HueSlider(
                          hue: a.customHue,
                          onChanged: (h) => app.setAppearance(app.appearance.copyWith(accent: AccentId.custom, customHue: h), persist: false),
                          onChangeEnd: () => app.setAppearance(app.appearance),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ]).separatedBy(const SizedBox(height: 16)),
    );
  }
}

class _EffectsTab extends StatelessWidget {
  final AppState app;
  const _EffectsTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: staggered([
        _Section(
          title: 'Style des surfaces',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  for (final s in SurfaceStyle.values) _SurfaceTile(style: s, app: app),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: appSwitchTransition,
                child: Row(
                  key: ValueKey(a.surface),
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: _Hint('${a.surface.label} — ${a.surface.description}')),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Section(title: 'Mouvement', child: _MotionDemo(app: app)),
        _Section(
          title: 'Arrondis',
          child: Row(
            children: [
              for (final (i, c) in CornerStyle.values.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _CornerTile(corners: c, app: app)),
              ],
            ],
          ),
        ),
      ]).separatedBy(const SizedBox(height: 16)),
    );
  }
}

/// The surface style's motion, to try out: how things come in — played
/// again whenever the style changes, or with the replay button — and how
/// they answer a finger.
class _MotionDemo extends StatefulWidget {
  final AppState app;
  const _MotionDemo({required this.app});

  @override
  State<_MotionDemo> createState() => _MotionDemoState();
}

class _MotionDemoState extends State<_MotionDemo> {
  int _replays = 0;
  bool _picked = true;

  @override
  Widget build(BuildContext context) {
    final a = widget.app.appearance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: appSwitchTransition,
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
          child: KeyedSubtree(key: ValueKey(a.surface), child: _Hint(AppColors.motion.description)),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey((a.surface, _replays)),
          child: Row(
            children: [
              Expanded(
                child: FadeSlideIn(
                  child: Pressable(
                    onTap: HapticFeedback.selectionClick,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: cardDecoration(radius: AppRadius.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: wellDecoration(radius: AppRadius.scaled(10)),
                            child: const Text('🎲', style: TextStyle(fontSize: 17)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Touchez-moi', maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: AppColors.ink))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FadeSlideIn(
                delay: staggerDelay(1, stepMs: 70),
                child: OptionChip(label: 'Choisi', selected: _picked, onTap: () => setState(() => _picked = !_picked)),
              ),
              const SizedBox(width: 10),
              FadeSlideIn(
                delay: staggerDelay(2, stepMs: 70),
                child: Pressable(
                  pressedScale: 0.92,
                  onTap: () => setState(() => _replays++),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: accentDecoration(radius: AppRadius.lg),
                    child: const Icon(Icons.replay_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (a.reduceMotion) ...[
          const SizedBox(height: 12),
          const _Hint('Les animations sont réduites (onglet Réglages) : tout apparaît sans bouger.'),
        ],
      ],
    );
  }
}

class _BackdropTab extends StatelessWidget {
  final AppState app;
  const _BackdropTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final canAnimate = a.backdrop.animatable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: staggered([
        _Section(
          title: 'Fond d’écran',
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final s in BackdropStyle.values) _BackdropTile(style: s, app: app),
            ],
          ),
        ),
        _Section(
          title: 'Mouvement',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SwitchRow(
                label: 'Animer le fond',
                value: canAnimate && a.animatedBackdrop,
                onChanged: canAnimate ? (v) => app.setAppearance(a.copyWith(animatedBackdrop: v)) : null,
              ),
              const SizedBox(height: 6),
              _Hint(canAnimate
                  ? (a.reduceMotion ? 'En pause : les animations sont réduites (onglet Réglages).' : 'Le fond dérive tout doucement, en boucle.')
                  : 'Aurore, Maillage, Vagues, Bulles et Étoiles peuvent s’animer.'),
            ],
          ),
        ),
        if (a.surface == SurfaceStyle.glass && a.backdrop == BackdropStyle.none)
          const _Tip('Le verre se révèle sur un fond coloré : essayez Aurore ou Maillage.'),
      ]).separatedBy(const SizedBox(height: 16)),
    );
  }
}

class _TextTab extends StatelessWidget {
  final AppState app;
  const _TextTab({required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: staggered([
        _Section(
          title: 'Police',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              for (final f in FontPair.values) _FontTile(font: f, app: app),
            ],
          ),
        ),
        _Section(
          title: 'Taille du texte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedControl(
                labels: [for (final s in TextSize.values) s.label],
                selectedIndex: TextSize.values.indexOf(a.textSize),
                fontSize: 12,
                onChanged: (i) => app.setAppearance(a.copyWith(textSize: TextSize.values[i])),
              ),
              const SizedBox(height: 12),
              Text('Léa remporte la partie de Catan avec 12 points.', style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 2),
              const _Hint('S’ajoute à la taille choisie dans les réglages de votre appareil.'),
            ],
          ),
        ),
      ]).separatedBy(const SizedBox(height: 16)),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  final AppState app;
  const _SettingsTab({required this.app});

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text('Réinitialiser l’apparence ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
        content: Text('Couleurs, effets, fond, police et barre de navigation reviennent au style d’origine de Podium.', style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('Réinitialiser', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (confirmed == true) {
      await app.setAppearance(const Appearance());
      app.showToast('Apparence d’origine rétablie.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final dashboardIndex = switch (app.dashboardStyle) { DashboardStyle.simple => 0, DashboardStyle.complete => 1 };
    final isDefault = a == const Appearance();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: staggered([
        _Section(
          title: 'Tableau de bord',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedControl(
                labels: const ['Épuré', 'Complet'],
                selectedIndex: dashboardIndex,
                onChanged: (i) => app.setDashboardStyle(switch (i) { 0 => DashboardStyle.simple, _ => DashboardStyle.complete }),
              ),
              const SizedBox(height: 10),
              _Hint(app.dashboardStyle == DashboardStyle.simple ? 'Écran d’accueil simplifié, avec juste l’essentiel.' : 'Écran d’accueil complet, avec classement et statistiques détaillées.'),
            ],
          ),
        ),
        _Section(
          title: 'Barre de navigation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedControl(
                labels: [for (final s in NavBarStyle.values) s.label],
                selectedIndex: NavBarStyle.values.indexOf(a.navBar),
                onChanged: (i) => app.setAppearance(a.copyWith(navBar: NavBarStyle.values[i])),
              ),
              const SizedBox(height: 12),
              _SwitchRow(label: 'Libellés sous les icônes', value: a.navLabels, onChanged: (v) => app.setAppearance(a.copyWith(navLabels: v))),
            ],
          ),
        ),
        _Section(
          title: 'Animations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SwitchRow(label: 'Réduire les animations', value: a.reduceMotion, onChanged: (v) => app.setAppearance(a.copyWith(reduceMotion: v))),
              const SizedBox(height: 6),
              const _Hint('Les écrans apparaissent sans glisser, les touches répondent sans s’animer et les décors animés restent immobiles.'),
            ],
          ),
        ),
        Pressable(
          onTap: isDefault ? null : () => _confirmReset(context),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDefault ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(radius: AppRadius.lg),
              child: Row(
                children: [
                  Icon(Icons.restart_alt_rounded, size: 20, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Réinitialiser l’apparence', style: bodyFont(size: 14.5, weight: FontWeight.w700, color: AppColors.ink))),
                  Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.mut),
                ],
              ),
            ),
          ),
        ),
      ]).separatedBy(const SizedBox(height: 16)),
    );
  }
}

// ============================== tiles ==============================

/// A theme preset: the app in miniature, dressed in it.
class _PresetTile extends StatelessWidget {
  final AppearancePreset preset;
  final bool selected;
  final AppState app;
  const _PresetTile({required this.preset, required this.selected, required this.app});

  @override
  Widget build(BuildContext context) {
    final dark = preset.mode == ThemeMode.dark || (preset.mode == null && app.isDark);
    final look = app.appearance.withLookOf(preset.look);
    final tokens = AppTokens.resolve(look, dark: dark);
    final plus = preset.look.paidParts.any(app.unlocks.marksPart);
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        _pick(
          context,
          app,
          locked: !preset.look.allowedBy(app.unlocks),
          pack: themePack(preset),
          title: '${preset.emoji}  Thème ${preset.label}',
          why: '${preset.description} Achetez-le pour en garder chaque élément, à mélanger avec le reste de vos réglages.',
          look: look,
          dark: dark,
          apply: () => app.applyAppearancePreset(preset),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SelectionRing(
              selected: selected,
              radius: AppRadius.lg,
              child: FittedBox(fit: BoxFit.cover, child: SizedBox.fromSize(size: AppearancePreview.designSize, child: AppearancePreview(tokens: tokens))),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(preset.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 13.5, weight: FontWeight.w800, color: selected ? AppColors.accent : AppColors.ink))),
                    // The night themes switch to dark mode too.
                    if (preset.mode == ThemeMode.dark) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.dark_mode_rounded, size: 13, color: AppColors.mut),
                    ],
                    if (plus) ...[
                      const SizedBox(width: 6),
                      const PlusMark(size: 16, tier: PlusTier.plusPlus),
                    ],
                  ],
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
              ),
            ],
          ),
          Text(preset.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11, weight: FontWeight.w600, color: AppColors.mut)),
        ],
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final PaletteId palette;
  final AppState app;
  const _PaletteSwatch({required this.palette, required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final selected = a.palette == palette;
    // The palette's own tones, without the surface style bending them.
    final t = AppTokens.resolve(a.copyWith(palette: palette, surface: SurfaceStyle.flat, backdrop: BackdropStyle.none), dark: app.isDark);
    return Pressable(
      onTap: () => app.setAppearance(a.copyWith(palette: palette)),
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            _SelectionRing(
              selected: selected,
              radius: 13,
              child: Container(
                width: 52,
                height: 52,
                color: t.bg,
                padding: const EdgeInsets.all(9),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(7), border: Border.all(color: t.line)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(height: 4, width: 20, decoration: BoxDecoration(color: t.ink, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 4),
                      Container(height: 4, width: 12, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(palette.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11, weight: FontWeight.w700, color: selected ? AppColors.accent : AppColors.mut)),
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final AccentId accent;
  final AppState app;
  const _AccentSwatch({required this.accent, required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final selected = a.accent == accent;
    final custom = accent == AccentId.custom;
    final color = custom ? accentForHue(a.customHue) : accent.color;
    final plus = app.unlocks.marksPart(accent);
    return Pressable(
      onTap: () => _pickPart(context, app, accent, look: a.copyWith(accent: accent), apply: () => app.setAppearance(a.copyWith(accent: accent))),
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: custom ? null : color,
                    gradient: custom ? SweepGradient(colors: [for (var h = 0; h <= 360; h += 45) accentForHue(h.toDouble())]) : null,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: AppColors.ink, width: 3) : null,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: AnimatedScale(
                    scale: selected || custom ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(custom && !selected ? Icons.tune_rounded : Icons.check, color: Colors.white, size: 19),
                  ),
                ),
                if (plus) const Positioned(top: -3, right: -9, child: PlusMark(size: 17, tier: PlusTier.plusPlus)),
              ],
            ),
            const SizedBox(height: 6),
            Text(accent.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11, weight: FontWeight.w700, color: selected ? AppColors.ink : AppColors.mut)),
          ],
        ),
      ),
    );
  }
}

/// Any hue, along a rainbow of the accents it would give.
class _HueSlider extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;
  const _HueSlider({required this.hue, required this.onChanged, required this.onChangeEnd});

  static const _thumb = 30.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final travel = box.maxWidth - _thumb;
        void update(double dx) => onChanged(((dx - _thumb / 2) / travel).clamp(0.0, 1.0) * 360);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx),
          onTapUp: (_) => onChangeEnd(),
          onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
          onHorizontalDragEnd: (_) => onChangeEnd(),
          child: SizedBox(
            height: 38,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: _thumb / 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: LinearGradient(colors: [for (var h = 0; h <= 360; h += 30) accentForHue(h.toDouble())]),
                  ),
                ),
                Positioned(
                  left: hue / 360 * travel,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: accentForHue(hue),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A surface style shown on its own: a card, a call to action and a chip.
class _SurfaceTile extends StatelessWidget {
  final SurfaceStyle style;
  final AppState app;
  const _SurfaceTile({required this.style, required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final selected = a.surface == style;
    // Glass is only glass over something: give it a backdrop to show.
    final look = a.copyWith(surface: style, backdrop: style == SurfaceStyle.glass && a.backdrop == BackdropStyle.none ? BackdropStyle.aurora : a.backdrop);
    final t = AppTokens.resolve(look, dark: app.isDark);
    final f = t.radiusFactor;
    final plus = app.unlocks.marksPart(style);
    Widget bar(Color c, double w) => Container(height: 5, width: w, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)));
    return Pressable(
      onTap: () => _pickPart(context, app, style, look: look, apply: () => app.setAppearance(a.copyWith(surface: style))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SelectionRing(
              selected: selected,
              radius: AppRadius.lg,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  look.backdrop == BackdropStyle.none ? ColoredBox(color: t.bg) : BackdropView(tokens: t, still: true),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 40,
                          padding: const EdgeInsets.all(7),
                          decoration: t.surface(radius: 12 * f),
                          child: Row(
                            children: [
                              Container(width: 26, decoration: t.well(radius: 8 * f)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [bar(t.ink, 46), const SizedBox(height: 4), bar(t.mut, 28)],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(height: 20, width: 46, decoration: t.accentButton(radius: 7 * f)),
                            const SizedBox(width: 8),
                            Container(height: 20, width: 32, decoration: t.surface(radius: 999, depth: 0.55)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (plus) const Positioned(bottom: 8, right: 8, child: PlusMark(size: 18, tier: PlusTier.plusPlus)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(style.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12, weight: FontWeight.w800, color: selected ? AppColors.accent : AppColors.ink2)),
        ],
      ),
    );
  }
}

class _CornerTile extends StatelessWidget {
  final CornerStyle corners;
  final AppState app;
  const _CornerTile({required this.corners, required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final selected = a.corners == corners;
    final color = selected ? AppColors.accent : AppColors.ink2;
    return Pressable(
      onTap: () => app.setAppearance(a.copyWith(corners: corners)),
      child: AnimatedContainer(
        duration: AppColors.motion.change,
        curve: AppColors.motion.changeCurve,
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        decoration: chipDecoration(radius: AppRadius.md, fill: selected ? AppColors.accentSoft : null, border: selected ? AppColors.accent : null, borderWidth: 1.5, selected: selected),
        child: Column(
          children: [
            // The top-left corner of a card, at this style's radius.
            Container(
              width: 30,
              height: 24,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: color, width: 3), left: BorderSide(color: color, width: 3)),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20 * corners.factor)),
              ),
            ),
            const SizedBox(height: 6),
            Text(corners.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 10.5, weight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}

class _BackdropTile extends StatelessWidget {
  final BackdropStyle style;
  final AppState app;
  const _BackdropTile({required this.style, required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final selected = a.backdrop == style;
    final plus = app.unlocks.marksPart(style);
    return Pressable(
      onTap: () => _pickPart(context, app, style, look: a.copyWith(backdrop: style), apply: () => app.setAppearance(a.copyWith(backdrop: style))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SelectionRing(
              selected: selected,
              radius: AppRadius.md,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BackdropView(tokens: AppColors.tokens, style: style, still: true),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Row(
                      children: [
                        if (style.animatable) const _Badge(icon: Icons.motion_photos_on_rounded),
                        if (style.animatable && plus) const SizedBox(width: 4),
                        if (plus) const PlusMark(size: 19, tier: PlusTier.plusPlus),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(style.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: selected ? AppColors.accent : AppColors.ink2)),
        ],
      ),
    );
  }
}

class _FontTile extends StatelessWidget {
  final FontPair font;
  final AppState app;
  const _FontTile({required this.font, required this.app});

  @override
  Widget build(BuildContext context) {
    final a = app.appearance;
    final selected = a.font == font;
    final families = font.bodyFamily == null ? 'Police de l’appareil' : '${font.bodyFamily} · ${font.displayFamily}';
    final plus = app.unlocks.marksPart(font);
    return Pressable(
      onTap: () => _pickPart(context, app, font, look: a.copyWith(font: font), apply: () => app.setAppearance(a.copyWith(font: font))),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          AnimatedContainer(
            duration: AppColors.motion.change,
            curve: AppColors.motion.changeCurve,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: chipDecoration(radius: AppRadius.lg, fill: selected ? AppColors.accentSoft : null, border: selected ? AppColors.accent : null, borderWidth: 1.5, selected: selected),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Aa', style: pairDisplayFont(font, size: 24, weight: FontWeight.w700, color: AppColors.ink, height: 1.1)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('123', maxLines: 1, style: pairDisplayFont(font, size: 16, weight: FontWeight.w700, color: AppColors.accent))),
                  ],
                ),
                const Spacer(),
                Text(font.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: pairBodyFont(font, size: 12.5, weight: FontWeight.w800, color: selected ? AppColors.accent : AppColors.ink2)),
                Text(families, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 10, weight: FontWeight.w600, color: AppColors.mut)),
              ],
            ),
          ),
          if (plus) const Positioned(top: 8, right: 8, child: PlusMark(size: 17, tier: PlusTier.plusPlus)),
        ],
      ),
    );
  }
}

// ============================== bits ==============================

/// A titled card of settings, in the surface style.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: AppRadius.xl),
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

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut, height: 1.35));
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: AppRadius.lg, fill: AppColors.accentSoft, border: AppColors.accent.withValues(alpha: 0.4)),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: AppColors.ink2))),
        ],
      ),
    );
  }
}

/// Clips [child] to a rounded tile, ringed in the accent once picked.
class _SelectionRing extends StatelessWidget {
  final bool selected;
  final double radius;
  final Widget child;
  const _SelectionRing({required this.selected, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 3),
        border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 2.5 : 1),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  const _Badge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Pressable(
      behavior: HitTestBehavior.opaque,
      pressedScale: 0.98,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Row(
          children: [
            Expanded(child: Text(label, style: bodyFont(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
            _Toggle(value: value),
          ],
        ),
      ),
    );
  }
}

/// An on/off switch in the surface style: a hollow track that fills with
/// the accent, and a raised knob.
class _Toggle extends StatelessWidget {
  final bool value;
  const _Toggle({required this.value});

  @override
  Widget build(BuildContext context) {
    final motion = AppColors.motion;
    return AnimatedContainer(
      duration: motion.change,
      curve: motion.changeCurve,
      width: 50,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: value ? accentDecoration(radius: 15) : AppColors.tokens.track(radius: 15),
      // The knob travels at the style's pace — wobbling in clay, but
      // stopped by the ends of the track.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value ? 1 : -1),
        duration: motion.style == SurfaceStyle.flat ? const Duration(milliseconds: 220) : motion.move,
        curve: motion.style == SurfaceStyle.flat ? Curves.easeOutBack : motion.moveCurve,
        builder: (context, x, child) => Align(alignment: Alignment(x.clamp(-1.0, 1.0), 0), child: child),
        child: Container(width: 22, height: 22, decoration: chipDecoration(shape: BoxShape.circle, fill: Colors.white, borderless: true)),
      ),
    );
  }
}

extension on List<Widget> {
  /// The widgets with [gap] between each.
  List<Widget> separatedBy(Widget gap) => [
        for (final (i, w) in indexed) ...[
          if (i > 0) gap,
          w,
        ],
      ];
}
