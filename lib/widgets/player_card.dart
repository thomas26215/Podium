import 'package:flutter/material.dart';

import '../logic/badges.dart';
import '../logic/plus.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
import 'badge_widgets.dart';
import 'profile_banners.dart';
import 'profile_style.dart';

export 'avatar.dart' show PlayerAvatar, AvatarCluster;

// A player's card — the look they gave their profile: banner, avatar
// decoration, name font and effect, title — carried everywhere they show
// up, not only on their profile: their decorated avatar (PlayerAvatar) and
// styled name wherever they appear, their banner as a nameplate wherever
// players are listed. All of it reads the card as everyone sees it
// (PlusProfile.shown): a paid pick only shows for whoever unlocked it.

extension DressedCard on AppUser {
  /// Whether the card everyone sees has a look of its owner's own — a
  /// banner, a decoration, a name font or effect. Such a player is listed
  /// on their [Nameplate]; anyone else in the app's plain row.
  bool get dressedUp {
    final c = shown;
    return c.banner != kDefaultBanner || c.avatarFrame != null || c.nameFont != null || c.nameEffect != null;
  }
}

/// [style] with [user]'s name font (see nameFontStyle) in place of its own,
/// keeping its size and colour: their name as they styled it on the app's
/// own surfaces, where their card's white-based effects wouldn't read.
/// [style] itself for whoever kept the app's font.
TextStyle playerNameStyle(AppUser? user, TextStyle style) {
  final font = user?.shown.nameFont;
  if (font == null) return style;
  return nameFontStyle(font, style.fontSize ?? 14).copyWith(color: style.color, shadows: style.shadows);
}

/// [text] as a span, the first mention of [user]'s name in it — as a whole
/// word — set in their font (see [playerNameStyle]): "Gagné par Léa ·
/// 10 pts".
TextSpan nameInText(String text, AppUser? user, TextStyle style) {
  final name = user?.displayName ?? '';
  final mention = name.isEmpty || user?.shown.nameFont == null ? null : RegExp('(?<![\\p{L}\\p{N}])${RegExp.escape(name)}(?![\\p{L}\\p{N}])', unicode: true).firstMatch(text);
  if (mention == null) return TextSpan(text: text, style: style);
  return TextSpan(style: style, children: [
    TextSpan(text: text.substring(0, mention.start)),
    TextSpan(text: name, style: playerNameStyle(user, style)),
    TextSpan(text: text.substring(mention.end)),
  ]);
}

/// [style] for text on a player's banner (a [Nameplate]): lifted off the
/// scene behind by a soft shadow, as on their card.
TextStyle onBanner(TextStyle style) => style.copyWith(shadows: const [Shadow(color: Color(0x8C000000), blurRadius: 6)]);

/// [user]'s name in their font (see [playerNameStyle]), on one line.
class PlayerName extends StatelessWidget {
  final AppUser? user;
  final TextStyle style;

  /// Written instead of the bare name: "Léa (vous)".
  final String? text;

  /// Written for a player not loaded yet, or gone.
  final String fallback;
  const PlayerName(this.user, {super.key, required this.style, this.text, this.fallback = '?'});

  @override
  Widget build(BuildContext context) => Text(text ?? user?.displayName ?? fallback, maxLines: 1, overflow: TextOverflow.ellipsis, style: playerNameStyle(user, style));
}

/// [user]'s name as their card draws it — their font and effect, white for
/// their banner (see StyledName) — held still unless [live].
class CardName extends StatelessWidget {
  final AppUser user;
  final double size;
  final bool live;
  const CardName(this.user, {super.key, this.size = 16, this.live = false});

  @override
  Widget build(BuildContext context) {
    final c = user.shown;
    return StyledName(text: c.displayName, fontId: c.nameFont, effectId: c.nameEffect, size: size, accent: Color(c.color), phase: live ? null : kStillNamePhase);
  }
}

/// The [title] a player wears under their name — "✦ Vainqueur", in the
/// tier colour of the badge that earned it — for their banner.
class CardTitle extends StatelessWidget {
  final TitleDef title;
  final double size;
  const CardTitle(this.title, {super.key, this.size = 12.5});

  /// [user]'s title, or null for none.
  static CardTitle? of(AppUser user, {double size = 12.5}) {
    final title = titleById(user.titleId);
    return title == null ? null : CardTitle(title, size: size);
  }

  @override
  Widget build(BuildContext context) {
    final badge = title.badgeId == null ? null : badgeById(title.badgeId!);
    return Text(
      '✦ ${title.label}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: bodyFont(size: size, weight: FontWeight.w800, color: badge == null ? Colors.white.withValues(alpha: 0.9) : badgeTierColors(badge.tier).to, letterSpacing: 0.3)
          .copyWith(shadows: const [Shadow(color: Color(0x80000000), blurRadius: 6)]),
    );
  }
}

/// [child] on [user]'s banner — their nameplate, wherever players are
/// listed: the banner held still unless [live], shaded towards its right
/// end where numbers go. What sits on it is drawn in white, like on their
/// card (see [onBanner]). Only the banner is clipped to [borderRadius]: a
/// decoration may reach past the plate.
class Nameplate extends StatelessWidget {
  final AppUser user;
  final BorderRadius borderRadius;
  final bool live;
  final Widget child;
  const Nameplate({super.key, required this.user, required this.borderRadius, this.live = false, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfileBannerBackground(themeId: user.shown.banner, phase: live ? null : kStillBannerPhase),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x00000000), Color(0x61000000)], stops: [0.5, 0.95]))),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
