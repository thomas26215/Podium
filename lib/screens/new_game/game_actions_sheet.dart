import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_rules_screen.dart';
import 'new_game_sheet.dart';

/// Opens the create/edit-game sub-view via [action] (`app.startEditingGame`
/// or `app.startNewGame`) and makes sure the new-game sheet is actually on
/// screen for it — reused from both inside that sheet (already open, so
/// this just flips its internal view) and from screens that live entirely
/// outside it (the games catalog), where the sheet needs to be opened fresh.
Future<void> _openGameForm(BuildContext context, AppState app, VoidCallback action) async {
  final alreadyOpen = app.sheetOpen;
  if (!alreadyOpen) app.openSheet();
  action();
  if (!alreadyOpen) await showNewGameSheet(context, app);
}

/// A tappable row used by the various "pick an action" bottom sheets around
/// game management (new game chooser, per-game long-press menu…).
class ChooserOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const ChooserOption({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: bodyFont(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(subtitle, style: bodyFont(size: 12, weight: FontWeight.w600, color: AppColors.mut)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Long-press (or "manage") menu on a game: edit its settings (including
/// adding/removing scoring rules), browse/edit its rules reminders, or
/// (root owner only) delete it — shared between the new-game picker and the
/// standalone games catalog.
Future<void> showGameActionsSheet(BuildContext context, AppState app, Game game) async {
  // A closed group/salon is frozen against catalog changes (see
  // AppState.setGroupClosed/setSalonClosed) — only offer read-only actions there.
  final closed = app.activeContextClosed;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(game.name, style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 16),
          if (!closed) ...[
            ChooserOption(
              icon: Icons.tune_rounded,
              title: 'Modifier les paramètres',
              subtitle: 'Comptage, limite de points, rôles, manches multiples — et plusieurs règles possibles.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openGameForm(context, app, () => app.startEditingGame(game));
              },
            ),
            const SizedBox(height: 10),
          ],
          ChooserOption(
            icon: Icons.menu_book_rounded,
            title: 'Aide-mémoire',
            subtitle: 'Ajoutez des rappels de règles, classés par catégorie — sans effet sur les scores.',
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameRulesScreen(game: game)));
            },
          ),
          if (app.canManageGameCatalog && !closed) ...[
            const SizedBox(height: 10),
            ChooserOption(
              icon: Icons.delete_outline_rounded,
              title: 'Supprimer',
              subtitle: 'Supprime ce jeu et toutes les parties enregistrées pour lui.',
              onTap: () {
                Navigator.of(sheetContext).pop();
                confirmDeleteGame(context, app, game);
              },
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> confirmDeleteGame(BuildContext context, AppState app, Game game) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Text('Supprimer « ${game.name} » ?', style: dispFont(size: 18, weight: FontWeight.w700, color: AppColors.ink)),
      content: Text(
        'Cette action est définitive : toutes les parties enregistrées pour ce jeu seront supprimées.',
        style: bodyFont(size: 14, weight: FontWeight.w600, color: AppColors.mut),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
    ),
  );
  if (confirmed == true) await app.deleteGame(game.id);
}
