import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/badge_widgets.dart';
import '../../widgets/common.dart';
import '../chat/group_chat_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../new_game/new_game_sheet.dart';
import '../ranking/ranking_screen.dart';
import '../solo/solo_games_screen.dart';
import '../solo/solo_home_screen.dart';
import '../solo/solo_records_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [AppTab.home, AppTab.ranking, AppTab.history, AppTab.games];

  /// "Mon espace solo" has its own screens (see `AppState.isPersonalContext`),
  /// "Mes jeux" standing in for the groups' Discussion.
  static const _soloTabs = [AppTab.home, AppTab.ranking, AppTab.history, AppTab.soloGames];

  Future<void> _openNewGameSheet(BuildContext context, AppState app) async {
    if (app.activeContextClosed) {
      app.showToast('Ce groupe est clos — plus aucune nouvelle partie ne peut y être ajoutée.', error: true);
      return;
    }
    HapticFeedback.mediumImpact();
    app.openSheet();
    await showNewGameSheet(context, app);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final solo = app.isPersonalContext;
    final index = (solo ? _soloTabs : _tabs).indexOf(app.tab).clamp(0, 3);
    final floating = app.appearance.navBar == NavBarStyle.floating;
    final labels = app.appearance.navLabels;
    final fabSize = floating ? 50.0 : 58.0;
    final items = Row(
      children: [
        _NavItem(icon: Icons.home_rounded, label: 'Accueil', showLabel: labels, selected: app.tab == AppTab.home, onTap: () => app.setTab(AppTab.home)),
        _NavItem(icon: Icons.emoji_events_rounded, label: solo ? 'Records' : 'Classement', showLabel: labels, selected: app.tab == AppTab.ranking, onTap: () => app.setTab(AppTab.ranking)),
        SizedBox(
          width: 64,
          child: Center(
            child: Pressable(
              onTap: () => _openNewGameSheet(context, app),
              pressedScale: 0.9,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: app.activeContextClosed ? 0.4 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: fabSize,
                  height: fabSize,
                  decoration: accentDecoration(radius: AppRadius.scaled(floating ? 17 : 20), strong: !floating),
                  // Springs in on first appearance (and whenever the
                  // shell is rebuilt for another context).
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) => Transform.rotate(angle: -0.8 * (1 - t), child: Transform.scale(scale: t, child: child)),
                    child: Icon(Icons.add, color: Colors.white, size: floating ? 26 : 28),
                  ),
                ),
              ),
            ),
          ),
        ),
        _NavItem(icon: Icons.schedule_rounded, label: 'Parties', showLabel: labels, selected: app.tab == AppTab.history, onTap: () => app.setTab(AppTab.history)),
        if (solo)
          _NavItem(icon: Icons.sports_esports_rounded, label: 'Mes jeux', showLabel: labels, selected: app.tab == AppTab.soloGames, onTap: () => app.setTab(AppTab.soloGames))
        else
          _NavItem(
            icon: Icons.forum_rounded,
            label: 'Discussion',
            showLabel: labels,
            selected: app.tab == AppTab.games,
            onTap: () => app.setTab(AppTab.games),
            showBadge: app.tab != AppTab.games && app.hasUnreadDiscussionMessages,
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _FadeIndexedStack(
              key: ValueKey(solo),
              index: index,
              children: solo
                  ? const [SoloHomeScreen(), SoloRecordsScreen(), HistoryScreen(), SoloGamesScreen()]
                  : const [HomeScreen(), RankingScreen(), HistoryScreen(), GroupChatScreen()],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 100,
              child: IgnorePointer(
                child: _ToastHost(message: app.toast, error: app.toastIsError),
              ),
            ),
            if (app.pendingBadgeUnlocks.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                top: 8,
                child: BadgeUnlockBanner(
                  // A new batch restarts the celebration from the top.
                  key: ValueKey(app.pendingBadgeUnlocks.join(',')),
                  badgeIds: app.pendingBadgeUnlocks,
                  onDone: app.dismissBadgeUnlocks,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: floating
            // A pill in the surface style, floating off the bottom edge.
            ? Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                child: Container(
                  height: labels ? 68 : 60,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: AppColors.tokens.floatingBar(radius: AppRadius.scaled(26)),
                  child: items,
                ),
              )
            : Container(
                height: labels ? 78 : 68,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Fades from the *current* background, not a fixed light
                    // one — a transparent light beige would haze the dark
                    // theme; and over a backdrop, there's nothing to fade.
                    colors: [AppColors.canvas.withValues(alpha: 0), AppColors.canvas],
                    stops: const [0, 0.4],
                  ),
                ),
                child: items,
              ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;
  final bool showLabel;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.showBadge = false, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.mut;
    return Expanded(
      child: Pressable(
        behavior: HitTestBehavior.opaque,
        pressedScale: 0.9,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppColors.motion.change,
              curve: AppColors.motion.changeCurve,
              padding: const EdgeInsets.all(7),
              // In the surface style: hollowed into the bar in neumorphism,
              // a glowing tube in neon…
              decoration: selected ? AppColors.tokens.navIndicator(radius: AppRadius.scaled(11)) : BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.scaled(11))),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    child: Icon(icon, size: 22, color: color),
                  ),
                  Positioned(
                    top: -1,
                    right: -1,
                    child: AnimatedScale(
                      scale: showBadge ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: showBadge ? Curves.elasticOut : Curves.easeIn,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 1.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: bodyFont(size: 10.5, weight: FontWeight.w700, color: color),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Brings the toast in and out — slid up and springing in the original
/// style, dropped in hard in neo-brutalism, struck on in neon… — and keeps
/// showing the *last* message while it goes away, instead of the pill
/// emptying out the instant `AppState.toast` is cleared.
class _ToastHost extends StatefulWidget {
  final String message;
  final bool error;
  const _ToastHost({required this.message, required this.error});

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> with SingleTickerProviderStateMixin {
  late String _shown = widget.message;
  late bool _shownError = widget.error;
  late final AnimationController _c = AnimationController(vsync: this, value: widget.message.isEmpty ? 0 : 1);

  @override
  void didUpdateWidget(_ToastHost old) {
    super.didUpdateWidget(old);
    if (widget.message.isNotEmpty) {
      _shown = widget.message;
      _shownError = widget.error;
    }
    final visible = widget.message.isNotEmpty;
    if (visible != old.message.isNotEmpty) {
      final motion = AppColors.motion;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = visible ? 1 : 0;
      } else if (visible) {
        _c.animateTo(1, duration: motion.entrance(const Duration(milliseconds: 320)), curve: Curves.linear);
      } else {
        _c.animateBack(0, duration: const Duration(milliseconds: 260), curve: Curves.linear);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppColors.motion;
    final toast = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      // A new message while one is already up swaps in place.
      transitionBuilder: appSwitchTransition,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomCenter, children: [...previous, ?current]),
      child: _Toast(key: ValueKey(_shown), message: _shown, error: _shownError),
    );
    if (motion.style == SurfaceStyle.flat) {
      // The original: slid up from below, springing in.
      return AnimatedBuilder(
        animation: _c,
        child: toast,
        builder: (context, child) {
          final visible = _c.status != AnimationStatus.reverse;
          final e = (visible ? Curves.easeOutBack : Curves.easeInCubic).transform(_c.value);
          return FractionalTranslation(
            translation: Offset(0, 0.5 * (1 - e)),
            child: Transform.scale(scale: 0.92 + 0.08 * e, child: Opacity(opacity: Curves.easeOut.transform(_c.value), child: child)),
          );
        },
      );
    }
    return Reveal(animation: _c, motion: motion, travel: 24, anchor: Alignment.bottomCenter, child: toast);
  }
}

class _Toast extends StatelessWidget {
  final String message;
  final bool error;
  const _Toast({super.key, required this.message, required this.error});

  @override
  Widget build(BuildContext context) {
    final flat = AppColors.tokens.style == SurfaceStyle.flat;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      // The always-dark pill: floating on its own shadow in the original
      // style, in the surface style otherwise.
      decoration: flat
          ? BoxDecoration(color: AppColors.hero, borderRadius: BorderRadius.circular(16), boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12)),
            ])
          : heroDecoration(radius: AppRadius.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: error ? AppColors.accent : AppColors.green, shape: BoxShape.circle),
            child: Icon(error ? Icons.priority_high_rounded : Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(message, style: bodyFont(size: 14, weight: FontWeight.w700, color: Colors.white))),
        ],
      ),
    );
  }
}

/// [IndexedStack] that brings the newly selected tab in instead of
/// hard-cutting, in the player's surface style — a fade with a slight rise
/// in the original one, from the side it's on for the styles that slide
/// sideways, through a frost in glass… — while still keeping every tab
/// alive, so scroll positions and in-progress input survive switching.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _FadeIndexedStack({super.key, required this.index, required this.children});

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 1);

  /// Where the tab being brought in sits relative to the last one.
  double _side = 1;

  @override
  void didUpdateWidget(_FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _side = widget.index > old.index ? 1 : -1;
      final motion = AppColors.motion;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _c.duration = still ? const Duration(milliseconds: 160) : (motion.style == SurfaceStyle.flat ? const Duration(milliseconds: 260) : motion.entrance(const Duration(milliseconds: 280)));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One shape whatever the style, so restyling never rebuilds the tabs.
    return Reveal(
      animation: _c,
      motion: AppColors.motion,
      travel: 12,
      side: _side,
      amplitude: 0.35,
      anchor: Alignment.topCenter,
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
