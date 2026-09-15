import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../games/games_catalog_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../new_game/new_game_sheet.dart';
import '../ranking/ranking_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [AppTab.home, AppTab.ranking, AppTab.history, AppTab.games];

  Future<void> _openNewGameSheet(BuildContext context, AppState app) async {
    if (app.activeContextClosed) {
      app.showToast('Ce groupe est clos — plus aucune nouvelle partie ne peut y être ajoutée.');
      return;
    }
    app.openSheet();
    await showNewGameSheet(context, app);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final index = _tabs.indexOf(app.tab);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              index: index,
              children: const [
                HomeScreen(),
                RankingScreen(),
                HistoryScreen(),
                GamesCatalogScreen(),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 100,
              child: IgnorePointer(
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: app.toast.isNotEmpty ? Offset.zero : const Offset(0, 0.4),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: app.toast.isNotEmpty ? 1 : 0,
                    child: _Toast(message: app.toast),
                  ),
                ),
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
              colors: [const Color(0x00F4F2EC), AppColors.bg],
              stops: const [0, 0.4],
            ),
          ),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: app.tab == AppTab.home, onTap: () => app.setTab(AppTab.home)),
              _NavItem(icon: Icons.emoji_events_rounded, label: 'Classement', selected: app.tab == AppTab.ranking, onTap: () => app.setTab(AppTab.ranking)),
              SizedBox(
                width: 64,
                child: Center(
                  child: Pressable(
                    onTap: () => _openNewGameSheet(context, app),
                    pressedScale: 0.9,
                    child: Opacity(
                      opacity: app.activeContextClosed ? 0.4 : 1,
                      child: Container(
                        width: 58,
                        height: 58,
                        margin: const EdgeInsets.only(top: 0),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 10))],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(icon: Icons.schedule_rounded, label: 'Parties', selected: app.tab == AppTab.history, onTap: () => app.setTab(AppTab.history)),
              _NavItem(icon: Icons.casino_rounded, label: 'Jeux', selected: app.tab == AppTab.games, onTap: () => app.setTab(AppTab.games)),
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
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.mut;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: selected ? AppColors.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(11)),
              child: AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(icon, size: 22, color: color),
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

class _Toast extends StatelessWidget {
  final String message;
  const _Toast({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12)),
      ]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(message, style: bodyFont(size: 14, weight: FontWeight.w700, color: Colors.white))),
        ],
      ),
    );
  }
}
