import 'package:flutter/material.dart';

import '../../logic/plus.dart';
import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../theme/backdrop.dart';
import '../../widgets/appearance_preview.dart';
import '../../widgets/avatar.dart';
import '../../widgets/profile_banners.dart';
import '../../widgets/profile_style.dart';

/// What a Boutique item is called: "Aurore boréale", "Verre"…
String shopItemLabel(ShopItem item) {
  String from(List<({String? id, String label})> catalog) => catalog.where((e) => e.id == item.id).firstOrNull?.label ?? item.id;
  return switch (itemPart(item)) {
    SurfaceStyle s => s.label,
    FontPair f => f.label,
    BackdropStyle b => b.label,
    AccentId a => a.label,
    _ => switch (item.kind) {
        ShopKind.banner => bannerThemeById(item.id).label,
        ShopKind.frame => from(kAvatarFrames),
        ShopKind.nameFont => from(kNameFonts),
        ShopKind.nameEffect => from(kNameEffects),
        ShopKind.profileEffect => from([for (final e in kProfileEffects) (id: e.id, label: e.label)]),
        _ => item.id,
      },
  };
}

/// [user]'s card wearing [item] — what the Boutique shows a card cosmetic
/// on (a part of the interface leaves it as it is).
AppUser wearing(AppUser user, ShopItem item) => switch (item.kind) {
      ShopKind.banner => user.copyWith(banner: item.id),
      ShopKind.frame => user.copyWith(avatarFrame: () => item.id),
      ShopKind.nameFont => user.copyWith(nameFont: () => item.id),
      ShopKind.nameEffect => user.copyWith(nameEffect: () => item.id),
      ShopKind.profileEffect => user.copyWith(profileEffect: () => item.id),
      _ => user,
    };

/// The player's [base] look with [item] — a part of the interface — put on
/// it: what the Boutique shows it on. Glass is only glass over something,
/// so it comes with a backdrop when the look has none.
Appearance lookWith(Appearance base, ShopItem item) {
  final part = itemPart(item);
  if (part == null) return base;
  final look = base.withPart(part);
  return part == SurfaceStyle.glass && look.backdrop == BackdropStyle.none ? look.copyWith(backdrop: BackdropStyle.aurora) : look;
}

/// The app in miniature, in [look].
Widget lookPreview(Appearance look, {required bool dark}) {
  return FittedBox(fit: BoxFit.cover, child: SizedBox.fromSize(size: AppearancePreview.designSize, child: AppearancePreview(tokens: AppTokens.resolve(look, dark: dark))));
}

/// The app in miniature, dressed in [theme] over the player's [base] look.
Widget themePreview(AppearancePreset theme, {required Appearance base, required bool dark}) {
  return lookPreview(base.withLookOf(theme.look), dark: theme.mode == ThemeMode.dark || (theme.mode == null && dark));
}

/// A still picture of [item], filling its parent: the banner itself, the
/// frame round [user]'s avatar, their name in the font or effect, the
/// profile effect over a night card — or, for a part of the interface,
/// the app in that style, the background, the font, the colour.
class ShopItemThumb extends StatelessWidget {
  final ShopItem item;
  final AppUser user;

  /// The player's look and mode, for the parts of the interface.
  final Appearance base;
  final bool dark;
  const ShopItemThumb({super.key, required this.item, required this.user, required this.base, required this.dark});

  static const _night = BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF17151F), Color(0xFF2D2A3A)]));

  @override
  Widget build(BuildContext context) {
    final accent = Color(user.color);
    Widget onNight(Widget child) => DecoratedBox(decoration: _night, child: Center(child: child));
    final part = itemPart(item);
    switch (part) {
      case SurfaceStyle _:
        return lookPreview(lookWith(base, item), dark: dark);
      case BackdropStyle style:
        return BackdropView(tokens: AppTokens.resolve(base.copyWith(backdrop: style), dark: dark), style: style, still: true);
      case FontPair font:
        final t = AppTokens.resolve(base.copyWith(font: font), dark: dark);
        return ColoredBox(
          color: t.bg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            // Scaled down to fit a small thumbnail too.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Aa', style: pairDisplayFont(font, size: 30, weight: FontWeight.w700, color: t.ink, height: 1.1)),
                  const SizedBox(width: 8),
                  Text('1 245', style: pairDisplayFont(font, size: 18, weight: FontWeight.w700, color: t.accent)),
                ],
              ),
            ),
          ),
        );
      case AccentId _:
        return onNight(Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [for (var h = 0; h <= 360; h += 45) accentForHue(h.toDouble())])),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
        ));
    }
    return switch (item.kind) {
      ShopKind.banner => ProfileBannerBackground(themeId: item.id, phase: 0.35),
      ShopKind.frame => onNight(LayoutBuilder(builder: (context, box) {
          final s = (box.biggest.shortestSide * 0.56).clamp(24.0, 72.0);
          return FramedAvatar(frameId: item.id, size: s, phase: 0.3, child: Avatar(initial: user.initial, color: accent, size: s, fontSize: s * 0.42));
        })),
      ShopKind.nameFont => onNight(Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: StyledName(text: user.displayName, fontId: item.id, size: 22, accent: accent))),
      ShopKind.nameEffect => onNight(Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: StyledName(text: user.displayName, effectId: item.id, size: 22, accent: accent, phase: 0.3))),
      ShopKind.profileEffect => DecoratedBox(
          decoration: _night,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: ProfileEffectPainter(item.id, intro: null, ph: 0.35, ambient: 1)),
              Center(child: Text(kProfileEffects.where((e) => e.id == item.id).firstOrNull?.emoji ?? '✨', style: const TextStyle(fontSize: 30))),
            ],
          ),
        ),
      _ => const SizedBox.expand(),
    };
  }
}
