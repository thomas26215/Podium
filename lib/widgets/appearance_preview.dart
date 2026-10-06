import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/backdrop.dart';
import 'common.dart';

/// A miniature of the app — leader card, stat chips, a match, the bottom
/// bar — drawn entirely from [tokens], so any appearance can be shown next
/// to the live one (the settings' live preview, the theme presets).
class AppearancePreview extends StatelessWidget {
  final AppTokens tokens;

  /// Plays the surface style's entrance again whenever it changes — the
  /// live preview, showing off a newly picked effect.
  final bool replayOnStyleChange;
  const AppearancePreview({super.key, required this.tokens, this.replayOnStyleChange = false});

  /// The size it's laid out at, then scaled to fit.
  static const designSize = Size(340, 250);

  Widget _replay(Widget content) => replayOnStyleChange ? FadeSlideIn(key: ValueKey(tokens.appearance.surface), offsetY: -10, child: content) : content;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final a = t.appearance;
    final f = t.radiusFactor;
    TextStyle body(double size, FontWeight weight, Color color, [double? letterSpacing]) => pairBodyFont(a.font, size: size, weight: weight, color: color, letterSpacing: letterSpacing);
    TextStyle disp(double size, Color color) => pairDisplayFont(a.font, size: size, weight: FontWeight.w700, color: color, letterSpacing: -0.3);

    Widget stat(String value, String label) => Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: t.surface(radius: 14 * f),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, style: disp(16, t.ink)),
                Text(label, maxLines: 1, style: body(8.5, FontWeight.w600, t.mut)),
              ],
            ),
          ),
        );

    return MediaQuery.withNoTextScaling(
      child: FittedBox(
        child: SizedBox.fromSize(
          size: designSize,
          child: Stack(
            children: [
              Positioned.fill(child: a.backdrop == BackdropStyle.none ? ColoredBox(color: t.bg) : BackdropView(tokens: t, still: true)),
              _replay(Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: t.heroSurface(radius: 20 * f, depth: 0.7),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                            child: Text('L', style: body(15, FontWeight.w800, Colors.white)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('EN TÊTE', style: body(8, FontWeight.w800, Colors.white.withValues(alpha: 0.6), 0.8)),
                                Text('Léa', maxLines: 1, style: disp(18, Colors.white)),
                              ],
                            ),
                          ),
                          Text('1 245', style: disp(21, t.gold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [stat('12', 'parties'), const SizedBox(width: 8), stat('5', 'jeux'), const SizedBox(width: 8), stat('4', 'joueurs')]),
                    const SizedBox(height: 10),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(8),
                      decoration: t.surface(radius: 16 * f),
                      child: Row(
                        children: [
                          Container(width: 34, height: 34, alignment: Alignment.center, decoration: t.well(radius: 10 * f), child: const Text('🎲', style: TextStyle(fontSize: 16))),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Catan', maxLines: 1, style: body(11.5, FontWeight.w800, t.ink)),
                                Text('Tom l’emporte', maxLines: 1, style: body(9, FontWeight.w600, t.mut)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: t.surface(radius: 999, fill: t.accentSoft, depth: 0.5),
                            child: Text('+3', style: body(10, FontWeight.w800, t.accent)),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _MiniNavBar(tokens: t),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniNavBar extends StatelessWidget {
  final AppTokens tokens;
  const _MiniNavBar({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final f = t.radiusFactor;
    final floating = t.appearance.navBar == NavBarStyle.floating;
    Widget icon(IconData i, {bool selected = false}) => Container(
          width: 30,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? t.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(8 * f)),
          child: Icon(i, size: 17, color: selected ? t.ink : t.mut),
        );
    return Container(
      height: 42,
      padding: EdgeInsets.symmetric(horizontal: floating ? 8 : 4),
      decoration: floating ? t.floatingBar(radius: 18 * f) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          icon(Icons.home_rounded, selected: true),
          icon(Icons.emoji_events_rounded),
          Container(
            width: 32,
            height: 32,
            decoration: t.accentButton(radius: 11 * f),
            child: const Icon(Icons.add, color: Colors.white, size: 19),
          ),
          icon(Icons.schedule_rounded),
          icon(Icons.forum_rounded),
        ],
      ),
    );
  }
}
