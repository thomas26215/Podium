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

    return Scaffold(
      backgroundColor: AppColors.bg,
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
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Fades from the *current* background, not a fixed light one —
              // a transparent light beige would haze the dark theme.
              colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg],
              stops: const [0, 0.4],
            ),
          ),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: app.tab == AppTab.home, onTap: () => app.setTab(AppTab.home)),
              _NavItem(icon: Icons.emoji_events_rounded, label: solo ? 'Records' : 'Classement', selected: app.tab == AppTab.ranking, onTap: () => app.setTab(AppTab.ranking)),
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
                        width: 58,
                        height: 58,
                        margin: const EdgeInsets.only(top: 0),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 10))],
                        ),
                        // Springs in on first appearance (and whenever the
                        // shell is rebuilt for another context).
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.elasticOut,
                          builder: (context, t, child) => Transform.rotate(angle: -0.8 * (1 - t), child: Transform.scale(scale: t, child: child)),
                          child: const Icon(Icons.add, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(icon: Icons.schedule_rounded, label: 'Parties', selected: app.tab == AppTab.history, onTap: () => app.setTab(AppTab.history)),
              if (solo)
                _NavItem(icon: Icons.sports_esports_rounded, label: 'Mes jeux', selected: app.tab == AppTab.soloGames, onTap: () => app.setTab(AppTab.soloGames))
              else
                _NavItem(
                  icon: Icons.forum_rounded,
                  label: 'Discussion',
                  selected: app.tab == AppTab.games,
                  onTap: () => app.setTab(AppTab.games),
                  showBadge: app.tab != AppTab.games && app.hasUnreadDiscussionMessages,
                ),
            ],
          ),
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
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap, this.showBadge = false});

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
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: selected ? AppColors.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(11)),
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
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: bodyFont(size: 10.5, weight: FontWeight.w700, color: color),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides/scales the toast in and out — and keeps showing the *last*
/// message while it animates away, instead of the pill emptying out the
/// instant `AppState.toast` is cleared.
class _ToastHost extends StatefulWidget {
  final String message;
  final bool error;
  const _ToastHost({required this.message, required this.error});

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  late String _shown = widget.message;
  late bool _shownError = widget.error;

  @override
  void didUpdateWidget(_ToastHost old) {
    super.didUpdateWidget(old);
    if (widget.message.isNotEmpty) {
      _shown = widget.message;
      _shownError = widget.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.message.isNotEmpty;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
      offset: visible ? Offset.zero : const Offset(0, 0.5),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 320),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        scale: visible ? 1 : 0.92,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          // A new message while one is already up cross-fades in place.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomCenter, children: [...previous, ?current]),
            child: _Toast(key: ValueKey(_shown), message: _shown, error: _shownError),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  final String message;
  final bool error;
  const _Toast({super.key, required this.message, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: AppColors.hero, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12)),
      ]),
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

/// [IndexedStack] that fades (with a slight rise) into the newly selected
/// tab instead of hard-cutting — while still keeping every tab alive, so
/// scroll positions and in-progress input survive switching tabs.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const _FadeIndexedStack({super.key, required this.index, required this.children});

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  late final Animation<double> _curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(_FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(_curved),
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
