import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logical width of a share card (ResultShareCard, TournamentShareCard);
/// its height follows its content.
const kShareCardWidth = 360.0;

/// Width in pixels of the shared PNG (see showResultShareDialog).
const kShareImageWidth = 1080.0;

/// Fixed light palette — a shared image looks the same whatever theme the
/// sharer uses (see [AppColors] for the in-app, theme-dependent tokens).
class SharePalette {
  SharePalette._();
  static const bg = Color(0xFFF4F2EC);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF18171C);
  static const ink2 = Color(0xFF3A3944);
  static const mut = Color(0xFF8C8A93);
  static const line = Color(0x14181713);
  static const bronze = Color(0xFFB8B3A6);
  static const gold = Color(0xFFE8A93B);
  static const green = Color(0xFF1F9D57);

  /// The sharer's accent color (kept, since it's their own choice).
  static Color get accent => accentPreviewColor(AppColors.accentPreset);
}

/// "12 pts", "1 pt".
String sharePts(int n) => n.abs() <= 1 ? '$n pt' : '$n pts';

/// The card's outer shell: fixed width, light background, [children]
/// stacked, and the "Podium · Disponible sur Google Play" footer.
class ShareCardFrame extends StatelessWidget {
  final List<Widget> children;
  const ShareCardFrame({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // Its own Material, so text never picks up the "no Material ancestor"
    // debug style wherever the card is rendered from.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: kShareCardWidth,
        color: SharePalette.bg,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            const SizedBox(height: 14),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

/// Emoji + big title, then a muted subtitle line and an optional accent pill.
class ShareCardHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? pill;
  const ShareCardHeader({super.key, required this.emoji, required this.title, required this.subtitle, this.pill});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: dispFont(size: 22, weight: FontWeight.w800, color: SharePalette.ink, letterSpacing: -0.3)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyFont(size: 12.5, weight: FontWeight.w700, color: SharePalette.mut)),
        if (pill != null && pill!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: SharePalette.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(pill!, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyFont(size: 11.5, weight: FontWeight.w800, color: SharePalette.accent)),
          ),
        ],
      ],
    );
  }
}

/// A titled white block (the score chart, the categories table…).
class ShareSection extends StatelessWidget {
  final String title;
  final Widget child;
  const ShareSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: SharePalette.card, border: Border.all(color: SharePalette.line, width: 1.5), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: bodyFont(size: 10.5, weight: FontWeight.w800, color: SharePalette.mut, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: SharePalette.accent, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 7),
        Text('Podium', style: dispFont(size: 15, weight: FontWeight.w800, color: SharePalette.ink)),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Disponible sur Google Play',
              textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 10.5, weight: FontWeight.w700, color: SharePalette.mut)),
        ),
      ],
    );
  }
}
