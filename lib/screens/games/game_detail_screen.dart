import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/game.dart';
import '../../services/game_rules_pdf.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_overview.dart';
import '../new_game/game_actions_sheet.dart';
import '../new_game/game_rules_screen.dart';

/// Read-first view of a single catalog game (see [GameOverview]) — with
/// quick access to edit its settings or reminders, or (root owner only)
/// delete it via the app bar menu.
class GameDetailScreen extends StatelessWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    // Keep showing the freshest copy (settings/rules might have just been
    // edited) instead of the one passed in when this screen was pushed.
    final current = app.gameById(game.id) ?? game;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(current.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: bodyFont(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf_rounded, color: AppColors.ink), tooltip: 'Exporter les règles en PDF', onPressed: () => exportGameRulesPdf(current)),
          IconButton(icon: Icon(Icons.more_vert_rounded, color: AppColors.ink), onPressed: () => showGameActionsSheet(context, app, current)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GameOverview(
            game: current,
            onEditReminders: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameRulesScreen(game: current))),
          ),
        ],
      ),
    );
  }
}
